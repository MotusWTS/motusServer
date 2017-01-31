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
#' \item  codeSet: X (optional codeset ; default: 4 for "Lotek4"; can also be 3 for "Lotek3")
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
    meta = list(motusProjID=NULL, tagModel=NULL, nomFreq=NULL, species=NULL, deployDate=NULL, codeSet=NULL)
    lcMetaNames = tolower(names(meta))
    p = jobPath(j)
    metaFile = dir(p, recursive=TRUE, pattern="tagreg.txt", ignore.case=TRUE, full.names=TRUE)
    if (length(metaFile) == 0)
        stop("Missing tagreg.txt metadata file")

    keyVal = splitToDF("(?<key>[[:alnum:]]+):[[:space:]]*(?<value>.*)", getFileAsText(metaFile), guess=FALSE)
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

    if (! isTRUE(projectID %in% projs$id)) {
        errs = c(errs, paste0("Invalid motus project id: ", meta$motusProjID))
    }

    tagModel = meta$tagModel
    if (! isTRUE(tagModel %in% rownames(tagLifespanPars))) {
        errs = c(errs, paste0("Invalid tag model: ", tagModel, "; must be one of:\n", paste(rownames(tagLifespanPars), collapse=", ")))
    }

    nomFreq = as.numeric(meta$nomFreq)
    if (! isTRUE(nomFreq >= 100 && nomFreq <= 200)) {
        errs = c(errs, paste0("Likely invalid tag nominal frequency: ", nomFreq, "; should be in the VHF range 100...200 MHz for motus"))
    }

    species = NULL
    if (! is.null(meta$species)) {
        species = as.integer(meta$species)
        if (is.na(species)) {
            sp = motusListSpecies(qstr=meta$species, qlng="CD")
            if (length(sp) == 0) {
                errs = c(errs, paste0("Unknown species code: ", meta$species))
            } else {
                species = sp$id[[1]]
            }
        }
    }

    deployDate = NULL
    if (! is.null(meta$deployDate)) {
        deployDate = ymd(meta$deployDate)
        if (is.na(deployDate)) {
            errs = c(errs, paste0("Could not parse deployment date: ", meta$deployDate, "\nShould be in form YYYY-MM-DD"))
        }
    }

    ## registration timestamp
    regTS = Sys.time()

    ## date for calculating dateBin
    dateBinTS = if (is.null(deployDate)) regTS else deployDate
    dateBin = sprintf("%4d-%1d", year(dateBinTS), ceiling(month(dateBinTS)/3))

    codeSet = "Lotek4"
    if (! is.null(meta$codeSet)) {
        codeSet = select( meta$codeSet,
                         "4" = "Lotek4",
                         "3" = "Lotek3",
                         "Lotek4" = "Lotek4",
                         "Lotek3" = "Lotek3",
                         "Lotek-4" = "Lotek4",
                         "Lotek-3" = "Lotek3",
                         NULL)
        if (is.null(codeSet))
            errs = c(errs, paste0("Unknown codeset: ", meta$codeSet, "\nShould be '4' or '3'"))
    }

    if (length(errs) > 0)
        stop(paste(errs, collapse="\n"))

    wavFiles = dir(p, recursive=TRUE, pattern="^.*tag[0-9]+(\\.[0-9])?(@[.0-9]+).wav$", ignore.case=TRUE, full.names=TRUE)

    ## extract data.frame of tag IDs as character strings
    info = splitToDF("(?i)tag(?<id>[0-9]+(?:\\.[0-9])?)(@(?<fcdfreq>[0-9]+\\.[0-9]*))?.wav$", basename(wavFiles), guess=FALSE)
    ids = info$id
    fcdfreqs = as.numeric(info$fcdfreq)

    ## ignore freq if user just gave us the nominal frequency
    if (all(fcdfreqs == nomFreq)) {
        jobLog(j, paste0("Please note: your filenames all have '@", sprintf("%.3f", nomFreq), "'.\n",
                      "The '@XXX.XXX' in filenames is for telling us the funcube listening frequency\n",
                      "rather than the nominal tag frequency, which is given in tagreg.txt file.\n",
                      "So I'm ignoring these, and assuming you set your funcube to ", sprintf("%.3f", nomFreq - 0.004), " MHz\n",
                      "which is what we recommend.  If that's not true, please email ", MOTUS_ADMIN_EMAIL, " with details.\n"))
        fcdfreqs = rep(NA, length(fcdfreqs))
    }
    ## set fcdfreq to default 4 kHz below nominal where not supplied
    fcdfreqs[is.na(fcdfreqs)] = nomFreq - 0.004

    ## get appropriate codeset DB and codeset DB file
    codeSetFile = ltGetCodeset(codeSet, pathOnly=TRUE)
    codeSetDB =  ltGetCodeset(codeSet,  pathOnly=FALSE)

    ## 2017-Jan-30 FIXME: remove provWarn cruft once upstream re-enables provisional deployment
    provWarn = FALSE

    ## process each wave file to look for tag detections
    numReg = 0
    numFail = 0
    numNoBISD = 0
    for (i in seq(along=wavFiles)) {
        ## return a data.frame of (ts, id, dfreq, sig, noise)
        tags = wavFindTags(wavFiles[i], codeSetFile)

        f = basename(wavFiles[i])
        if (nrow(tags) == 0) {
            jobLog(j, paste0("No tags detected in file ", f))
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
            ## allow for possibly missed bursts by retrying with
            tries = 0L
            maxTries = 5L
            while (tries < maxTries)  {
                meanbi = mean(bi)
                bi.sd = sd(bi)
                if (bi.sd <= maxBISD)
                    break
                tries = tries + 1L
                ## adjust bi by accounting for missed bursts at the current estimate of bi
                bi = bi / round(bi / meanbi)
            }
            if (! isTRUE(bi.sd  <= maxBISD)) {
                jobLog(j, paste0("Unable to get a good estimate of burst interval for tag id ", id, " in file ", f,
                                 "\nPlease re-record this tag and re-upload"))
                next
            }
        }
        dfreq = mean(tags$freq)
        dfreq.sd = sd(tags$freq)
        ## row in codeset corresponding to this id
        ii = match(id, codeSetDB$id)

        ## try register the tag with motus
        rv = tryCatch(
            motusRegisterTag(
                projectID = projectID,
                mfgID = ids[i],
                manufacturer = "Lotek",
                type = "ID",
                codeSet = codeSet,
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
                return (NULL)
            }
        )

        tag = paste0(id, ":", round(meanbi, 2))
        if (length(rv) > 0 && rv$responseCode == "success-import" && ! is.null(rv$tagID)) {
            jobLog(j, paste0("Success: tag ", tag, " was registered as motus tag ", rv$tagID, " under project ", projectID))
            if (! is.null(species) || ! is.null(deployDate)) {
                ## as of 2017 Jan 30; disabled pending upstream changes at motus.org
                if (! provWarn) {
                    jobLog(j, "You specified a provisional deployment date and/or species,\nbut this functionality is currently disabled.\n", summary=TRUE)
                    provWarn = TRUE
                }
                if (FALSE) { ## FIXME: re-enable when supported
                    ## try register a deployment on the given species and/or date
                    rv2 = motusDeployTag(tagID=as.integer(rv$tagID), speciesID=species, projectID=projectID, tsStart=as.numeric(deployDate))
                    msg = "with a deployment"
                    if (! is.null(deployDate))
                        msg = paste0(msg, " to start ", meta$deployDate)
                    if (! is.null(species))
                        msg = paste0(msg, " on a ", meta$species)
                    jobLog(j, msg)
                }
            }
            numReg = numReg + 1
        } else {
            jobLog(j, paste0("Query to motus server to register tag ", tag, " failed\nThis could be a server problem, or perhaps the tag is already registered."))
            numFail = numFail + 1
        }
    }
    jobLog(j, paste0("Registered ", numReg, " tags with motus.",
                     if (numFail > 0) paste0("\nWarning: another ", numFail, " tags failed to register"),
                     if (numNoBISD > 0) paste0("\nWarning: another ", numNoBISD, " tags had no estimate of BI error;\ntheir registrations might be faulty")
                     ), summary=TRUE)

    ## generate on-board tag database and mark it as an attachment to this job's completion email
    dbFile = createRecvTagDB(projectID, dateBin)
    topJob(j)$attachment = structure(dbFile, names=basename(dbFile))
    jobLog(j, "\nThe on-board database for your recent tags is attached.\nInstructions for installing it on a sensorgnome are here:\n   https://sensorgnome.org/VHF_Tag_Registration/Uploading_the_tags_database_file_to_your_SensorGnome\n", summary=TRUE)

    return(TRUE)
}
