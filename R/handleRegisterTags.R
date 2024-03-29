#' handle a batch of tag registrations
#'
#' Tag registrations are recordings of tag output accompanied by a
#' text file of metadata.  This function processes the recordings and
#' pushes the valid ones to motus.org
#'
#' @details
#' The job folder must contain a file called tagreg.txt with these lines:
#'
#' \itemize{
#' \item  motusProjID:  XXX (numeric project ID)
#' \item  tagModel: NTQB-??? (as given on the Lotek invoice)
#' \item  nomFreq: 166.38 (nominal tag frequency, in MHz)
#' \item  species: XXXXX (optional 4-letter code or motus numeric species ID)
#' \item  deployDate: YYYY-MM-DD (earliest likely deployment date for any tags)
#' \item  codeSet: X (optional codeset ; default: 6M for "Lotek6M"; can also be 4 for "Lotek4" or 3 for "Lotek3")
#' }
#'
#' as well as one or more recording files with names like \code{tagXXX.wav}
#' where \code{XXX} is the manufacturer's tag ID, typically 1 to 3 digits.
#' When there are recordings of tags with the same ID but different burst intervals,
#' the 2nd, 3rd, and so on such tags are given names like \code{tagXXX.1.wav, tagXXX.2.wav, ...}
#'
#' @note By default, we assume each tag was recorded at 4 kHz below
#'     its nominal frequency; e.g.  at 166.376 MHz for a nominal
#'     166.38 MHz tag.  If that's not true, the filename should
#'     include a portion of the form \code{@XXX.XXX} giving the
#'     frequency at which it was recorded;
#'     e.g. \code{tag134@166.372.wav} indicates a tag recorded at
#'     166.372 MHz, rather than the default.
#'
#' Called by \code{\link{processServer}}.
#'
#' @param j the job
#'
#' @return  TRUE;
#'
#' @seealso \code{\link{processServer}}, which calls this function.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleRegisterTags = function(j) {

    newTagIDs = integer(0)
    meta = list(motusProjID=NULL, tagModel=NULL, nomFreq=NULL, species=NULL, deployDate=NULL, codeSet=NULL)
    lcMetaNames = tolower(names(meta))
    p = jobPath(j)
    metaFile = dir(p, recursive=TRUE, pattern=MOTUS_TAGREG_MANIFEST_REGEXP, ignore.case=TRUE, full.names=TRUE)
    if (length(metaFile) == 0)
        stop("Missing tagreg.txt metadata file")

    keyVal = splitToDF("(?<key>[[:alnum:]]+):[[:space:]]*(?<value>[^[:space:]]*)", getFileAsText(metaFile), guess=FALSE)
    ## convert to named list, ignoring case of key values
    userMeta = list()
    userMeta[tolower(keyVal$key)] = keyVal$val

    ## copy over user-specified meta data with valid names, ignoring case
    for (i in seq(along=meta)) {
        if (isTRUE(nchar(userMeta[[lcMetaNames[i]]]) > 0))
            meta[[i]] = userMeta[[lcMetaNames[i]]]
    }

    ## validate metadata
    errs = character(0)

    projs = motusListProjects()
    projectID = as.integer(meta$motusProjID)
    if (length(projectID) > 0 && is.na(projectID)) {
        projectID = projs$id[grep(meta$motusProjID, projs$label)]
        if (length(projectID) != 1) {
            projectID = projs$id[grep(meta$motusProjID, projs$name)]
            if (length(projectID) != 1)
                projectID = NA
        }
    }
    if (! isTRUE(projectID %in% projs$id)) {
        errs = c(errs, paste0("Missing, invalid, or ambiguous Motus project ID: ", meta$motusProjID))
    }

    tagModel = meta$tagModel

    ## invoices sometimes don't show the "M" in the ANTC models,
    if (grepl("^ANTC", tagModel, perl=TRUE) && ! grepl("M", tagModel, perl=TRUE))
        tagModel = sub("([0-9])", "M\\1", tagModel, perl=TRUE) ## insert "M" before first digit

    ## Correct a common mistake (possibly another situation similar to the above?):
    if(grepl("^NTQB2-4-2s$", tagModel, perl=TRUE))
        tagModel = "NTQB2-4-2S"

    ## ignore hyphens when matching model
    tmi = match(gsub("-", "", tagModel, perl=TRUE), gsub("-", "", rownames(tagLifespanPars), perl=TRUE))
    if (is.na(tmi)) {
        errs = c(errs, paste0("Invalid tag model: ", tagModel, "; must be one of:\n", paste(sort(rownames(tagLifespanPars)), collapse="\n")))
    } else {
        ## fix up any hyphens so upstream recognizes the model string
        tagModel = rownames(tagLifespanPars)[tmi]
    }
    nomFreq = as.numeric(meta$nomFreq)
    if (! isTRUE(nomFreq >= 100 && nomFreq <= 200)) {
        errs = c(errs, paste0("Likely invalid tag nominal frequency: ", nomFreq, "; should be in the VHF range 100...200 MHz for motus"))
    }

    speciesID = NULL
    if (! is.null(meta$species)) {
        species = strsplit(meta$species, "[^a-zA-Z0-9]+", perl=TRUE)[[1]]
        if (length(species) > 1) {
            jobLog(j, "Warning: more than one species specified; only using the first", summary=TRUE)
            species = species[1]
        }
        speciesID = as.integer(species)
        if (is.na(speciesID)) {
            sp = motusListSpecies(qstr=species, qlang="CD")
            if (length(sp) == 0) {
                jobLog(j, paste("Warning: ignoring unknown species code:", species), summary=TRUE)
            } else {
                speciesID = sp$id[[1]]
            }
        }
    }

    deployDate = NA
    if (! is.null(meta$deployDate)) {
        deployDate = ymd(meta$deployDate, tz="GMT")
        if (is.na(deployDate)) {
            jobLog(j, paste0("Warning: could not parse deployment date: ", meta$deployDate, "\nShould be in form YYYY-MM-DD.\n"))
        }
    }

    ## registration timestamp
    regTS = Sys.time()

    ## date for calculating dateBin
    dateBinTS = if (is.na(deployDate)) regTS else deployDate
    dateBin = sprintf("%4d-%1d", year(dateBinTS), ceiling(month(dateBinTS)/3))

    ## Codeset Lotek6M was introduced in 2020. It completely overlaps with Lotek4, and add about 200 new values
    codeSet = "Lotek6M"
    if (! is.null(meta$codeSet)) {
        codeSet = switch( meta$codeSet,
                         "2003" = "Lotek4",
                         "Lotek-2003" = "Lotek4",
                         "Lotek 2003" = "Lotek4",
                         "4" = "Lotek4",
                         "3" = "Lotek3",
                         "Lotek4" = "Lotek4",
                         "Lotek3" = "Lotek3",
                         "Lotek-4" = "Lotek4",
                         "Lotek-3" = "Lotek3",
                         "Lotek6" = "Lotek6M",
                         "Lotek6M" = "Lotek6M",
                         "Lotek-6" = "Lotek6M",
                         "Lotek-6M" = "Lotek6M",
                         "6" = "Lotek6M",
                         "6M" = "Lotek6M",
                         "2020" = "Lotek6M",
                         "Lotek 2020" = "Lotek6M",
                         "Lotek-2020" = "Lotek6M",
                         NULL)
        if (is.null(codeSet))
            errs = c(errs, paste0("Unknown codeset: ", meta$codeSet, "\nShould be '6M', '4' or '3'"))
    }

    if (length(errs) > 0)
        stop(paste(errs, collapse="\n"))

    wavFiles = dir(p, recursive=TRUE, pattern="^.*tag[0-9]+(\\.[0-9])?(@[.0-9]+)?.wav$", ignore.case=TRUE, full.names=TRUE)

    if(length(wavFiles) == 0)
        stop("No .wav files matching the expected filename pattern found. They should be similar to 'tag123.wav', 'tag123.1.wav', or 'tag123@150.1.wav', case insensitive.")

    ## extract data.frame of tag IDs as character strings
    info = splitToDF("(?i)tag(?<id>[0-9]+(?:\\.[0-9])?)(@(?<fcdfreq>[0-9]+\\.[0-9]*))?.wav$", basename(wavFiles), guess=FALSE)
    ids = as.character(as.numeric(info$id))
    fcdfreqs = as.numeric(info$fcdfreq)

    ## ignore freq if user just gave us the nominal frequency
    if (isTRUE(length(fcdfreqs) > 0 && all(fcdfreqs == nomFreq))) {
        jobLog(j, paste0("Please note: your filenames all have '@", sprintf("%.3f", nomFreq), "'.\n",
                      "The '@XXX.XXX' in filenames is for telling us the funcube listening frequency\n",
                      "rather than the nominal tag frequency, which is given in tagreg.txt file.\n",
                      "So I'm ignoring these, and assuming you set your funcube to ", sprintf("%.3f", nomFreq - 0.004), " MHz\n",
                      "which is what we recommend.  If that's not true, please email ", MOTUS_ADMIN_EMAIL, " with details.\n"))
        fcdfreqs = rep(NA, length(fcdfreqs))
    }
    ## set fcdfreq to default 4 kHz below nominal where not supplied
    fcdfreqs[is.na(fcdfreqs)] = nomFreq - 0.004

    ## try all codesets
    otherCodeSets = if(codeSet=="Lotek4") c("Lotek6M","Lotek3") else if(codeSet=="Lotek3") c("Lotek6M","Lotek4") else c("Lotek4","Lotek3")
    tryingOtherCodeSet = 0
    numReg = 0
    numFail = 0
    numNoBISD = 0

    for (tryCodeSet in c(codeSet, otherCodeSets)) {
        ## get appropriate codeset DB and codeset DB file
        codeSetFile = ltGetCodeset(tryCodeSet, pathOnly=TRUE)
        codeSetDB = ltGetCodeset(tryCodeSet,  pathOnly=FALSE)

        ## 2017-Jan-30 FIXME: remove provWarn cruft once upstream re-enables provisional deployment
        provWarn = FALSE

        iNoTag = c()
        ## process each wave file to look for tag detections, using the current codeset
        for (i in seq(along=wavFiles)) {
            ## return a data.frame of (ts, id, dfreq, sig, noise)
            tags = wavFindTags(wavFiles[i], codeSetFile)

            f = basename(wavFiles[i])
            if (nrow(tags) == 0) {
                if (tryingOtherCodeSet > 0) {
                    jobLog(j, paste0("No tags detected in file ", f, " in alternative codest ", otherCodeSets[tryingOtherCodeSet]))
                } else {
                    jobLog(j, paste0("No tags detected in file ", f, ".  I'll retry below using the other codesets (",  paste0(otherCodeSets, collapse=","), ")"))
                }
                iNoTag = c(iNoTag, i)
                next
            }
            ## number of detections of the 'correct' tag
            id = as.integer(ids[i])
            n = sum(tags$id == id)
            if (n == 0) {
                err = paste0("Tag id ", id, " not found in file ", f)
                t = sort(table(tags$id), decreasing=TRUE)
                if (t[1] > 1) {
                    err = paste0(err, ", however, that file had ", t[1], " detections of id ", names(t)[1],
                                 "\nPerhaps the recording or the tag is mis-labelled?")
                }
                jobLog(j, err)
                next
            } else if (n < 2) {
                jobLog(j, paste0("Only 1 detection of id ", id, " found in file ", f, ", so I can't estimate burst interval."))
                next
            }
            tags = tags[tags$id == id,]
            bi = diff(sort(tags$ts))
            meanbi = mean(bi)
            if (length(bi) == 1) {
                jobLog(j, paste0("Warning: only 2 bursts detected for tag ", id, " so I can't estimate burst interval error.\nThis registration might not be accurate.\n"))
                numNoBISD = numNoBISD + 1
                bi.sd = 0
            } else {
                ## allow a maximum BI standard deviation of 5 ms
                maxBISD = 0.005
                tries = 0L
                maxTries = 5L
                while (tries < maxTries)  {
                    bi.sd = sd(bi)
                    if (isTRUE(bi.sd <= maxBISD))
                        break
                    ## allow for possibly missed bursts by retrying with successively
                    ## refined estimates of BI; start with the median, as mean
                    ## can easily prevent convergence in the presence of missing bursts.
                    if (tries == 0)
                        meanbi = median(bi)
                    tries = tries + 1L
                    bi = bi / round(bi / meanbi)
                    meanbi = mean(bi)
                }
                if (! isTRUE(bi.sd  <= maxBISD)) {
                    jobLog(j, paste0("Unable to get a good estimate of burst interval for tag id ", id, " in file ", f,
                                     "\nPlease re-record this tag and re-upload"))
                    numFail = numFail + 1
                    next
                }
            }
            dfreq = mean(tags$freq)
            dfreq.sd = sd(tags$freq)
            ## row in codeset corresponding to this id
            ii = match(id, codeSetDB$id)

            ## try register the tag with motus
            regError = FALSE
            rv = tryCatch(
                motusRegisterTag(
                    projectID = projectID,
                    mfgID = ids[i],
                    manufacturer = "Lotek",
                    type = "ID",
                    codeSet = tryCodeSet,
                    ## we want offset frequency relative to nominal, not to the recording listening frequency
                    offsetFreq = dfreq + 1000 * (fcdfreqs[i] - nomFreq),
                    period = meanbi,
                    periodSD = bi.sd,
                    pulseLen = 2.5,
                    param1 = codeSetDB$g1[ii],
                    param2 = codeSetDB$g2[ii],
                    param3 = codeSetDB$g3[ii],
                    param4 = 0.0,
                    param5 = 0.0,
                    param6 = 0.0,
                    paramType = 1,
                    ts = as.numeric(regTS),
                    nomFreq = nomFreq,
                    dateBin = dateBin,
                    model = tagModel
                ),
                error = function(e) {
                    regError <<- TRUE
                    return (jsonlite::fromJSON(as.character(e$message)))
                }
            )

            tag = paste0(id, ":", round(meanbi, 2))
            if (! regError) {
                jobLog(j, paste0("Success: tag ", tag, " was registered as motus tag ", rv$tagID, " under project ", projectID))
                newTagIDs = c(newTagIDs, rv$tagID)
                if (! is.null(speciesID) && ! is.na(deployDate)) {
                    ## try register a deployment on the given species and/or date
                    rv2 = motusDeployTag(tagID=as.integer(rv$tagID), speciesID=speciesID, projectID=projectID, tsStart=as.numeric(deployDate))
                    msg = "with a deployment"
                    if (! is.null(deployDate))
                        msg = paste0(msg, " to start ", meta$deployDate)
                    if (! is.null(speciesID))
                        msg = paste0(msg, " on a ", species)
                    jobLog(j, msg)
                }
                numReg = numReg + 1
            } else {
                jobLog(j, paste0("Query to motus server to register tag ", tag, " failed\nwith this error: ", rv$errorCode, ": ", rv$errorMsg))
                numFail = numFail + 1
            }
        }
        if (length(iNoTag) == 0)
            break
        tryingOtherCodeSet = tryingOtherCodeSet + 1
        wavFiles = wavFiles[iNoTag]
        ids = ids[iNoTag]
    }
    jobLog(j, paste0("Registered ", numReg, " tags with motus.",
                     if (numFail > 0) paste0("\nWarning: another ", numFail, " tags failed to register"),
                     if (numNoBISD > 0) paste0("\nWarning: ", numNoBISD, " tags had no estimate of BI error;\ntheir registrations might be faulty")
                     ), summary=TRUE)

    ## generate on-board tag database and mark it as an attachment to this job's completion email
    tj = topJob(j)
    isTesting = isTRUE(tj$isTesting)
    if (length(newTagIDs) > 0) {
        dbFile = createRecvTagDB(projectID, dateBin, isTesting)
        tj$attachment = structure(list(dbFile), names=basename(dbFile))
        url = getDownloadURL(projectID, isTesting)
        jobLog(j, sprintf("\nThe on-board database for your recent tags is available here:\n    %s\n\nInstructions for installing it on a sensorgnome are here:\n   https://archived.sensorgnome.org/VHF_Tag_Registration/Uploading_the_tags_database_file_to_your_SensorGnome\n", url), summary=TRUE)
        jobProduced(j, file.path(url, basename(dbFile)), projectID)
        ## directly update the tags, tagDeps, and events tables in the metadata cache
        ## and in the motus DB.  See:  https://github.com/jbrzusto/motusServer/issues/412
        newTags = subset(motusSearchTags(projectID=projectID), tagID %in% newTagIDs)
        if (isTRUE(nrow(newTags) > 0)) {
            MetaDB("BEGIN EXCLUSIVE TRANSACTION")
            updateMetadataForTags(newTags)
            commitMetadataHistory(MetaDB)
            MetaDB("COMMIT")
        }
    }
    return(TRUE)
}
