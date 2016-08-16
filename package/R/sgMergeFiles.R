#' Merge a batch of raw SG files with an existing receiver database.
#'
#' Determines which files are redundant, new, or partially new.  Does *not*
#' run the tag finder.
#'
#' @param files either a character vector of full paths to files, or
#'     the full path to a directory, which will be searched
#'     recursively for raw sensorgnome data files.
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{/sgm/recv}
#'
#' @return a list with two items:
#' \itemize{
#' \item info- a data_frame reporting the details of each file, with these columns:
#' \itemize{
#' \item name - full path to filename
#' \item use - TRUE iff data from this file will be incorporated in this run (i.e. the file is new, or has
#' more content than its previous version)
#' \item new  - TRUE iff a file of this name was not yet in database
#' \item done  - TRUE iff this is a compressed file and we have its full contents
#' \item corrupt      - TRUE the file was compressed but corrupted
#' \item small - TRUE iff the file contents are shorter than existing contents for that file in the receiver DB
#' \item partial - TRUE iff this is a partial compressed file for which an uncompressed version is in the same batch
#' \item serno - serial number of the receiver, parsed from this filename
#' \item monoBN - monotonic boot session, parsed from filename
#' \item ts - starting timestamp, parsed from filename
#' }
#' \item resumable - a logical vector indicating the tag finder can be run with --resume for each
#' subset of files from a distinct (serno, monoBN) pair.  The vector has names consisting of
#' \code{paste(serno, monoBN)}.
#' }
#'
#' Returns NULL if no valid sensorgnome data files were found.
#'
#' @export
#'
#' @seealso \code{sgRunNewFiles}, which calls this function and then calls \code{sgFindTags}
#' as appropriate.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgMergeFiles = function(files, dbdir = "/sgm/recv") {
    if (! isTRUE(is.character(files) && all(file.exists(files))))
        stop("invalid or non-existent input files specified")
    if (file.info(files[1])$isdir) {
        ff = dir(files, recursive=TRUE, full.names=TRUE)
    } else {
        ff = sort(files)
    }

    ## clean up the basename, in case there are wonky characters; we
    ## don't do this to "fullname", to maintain our ability to refer
    ## to the files from the filesystem.
    if (length(ff) == 0)
        return(NULL)
    allf = data_frame(
        ID       = 1:length(ff),
        fullname = ff,
        basename = ff %>% basename %>% iconv(to="UTF-8", sub="byte")
    )

    ## parse filenames into components
    pfc = parseFilenames(allf$basename)

    ## modify component names to avoid collisions with names in database 'files' table
    names(pfc) = paste0("F", names(pfc))

    ## On the SG, data are written simultaneously to .txt and .txt.gz files; when
    ## a size or time threshold is reached, the .txt.gz file is closed, and the
    ## uncompressed .txt version is deleted.  Until then, the .txt file will have
    ## more complete data.

    ## Moreover, separate data batches might both have partial copies of compressed
    ## and uncompressed versions of a file.

    ## Here's what we want to do:

    ## - once we have a complete, valid compressed file, preserve only that
    ##   one in the database.  So if the incoming data has a complete, valid compressed
    ##   file, preserve that and delete any existing .txt file.
    ##
    ## - otherwise, preserve only the .txt file in the database;
    ##
    ## - only update the .txt file if it is longer than the copy in the database, so that
    ##   we don't clobber existing data from a corrupt copy

    ## Here's what to do for each file (F) in the new set:
    ##
    ## - if F is in oldf and isDone is TRUE, we do nothing, as complete file is already present
    ## - otherwise, if an uncompressed F is in allf, then copy it to oldf if it is larger than
    ##   than any existing copy
    ## - otherwise, copy the compressed F (if valid) from allf to oldf.

    ## parse filenames into components
    pfc = parseFilenames(allf$basename)

    ## modify component names to avoid collisions with names in database 'files' table
    names(pfc) = paste0("F", names(pfc))

    ## bind parsed filename components
    allf = allf %>% bind_cols(pfc) %>% as.tbl  ## make sure it's a tbl; bind_cols wasn't behaving as doc'd

    ## add columns used in the return value:

    allf = allf %>%
        mutate (
            name     = stri_replace_all(basename, "",  regex="\\.(bz2|gz)$"),
            done     = FALSE,
            partial  = FALSE,
            nsize    = NA,
            small    = FALSE,
            new      = FALSE,
            use      = FALSE,
            corrupt  = FALSE
        )

    ## work with files from each receiver separately
    recvs = allf %>% select_("Fserno") %>% distinct_ %>% `[[` (1)

    nbadfiles = nrow(allf %>% filter_(~is.na(Fserno)))

    resumable = logical()

    for (recv in recvs) {
        if (is.na(recv))
            next
        ri = allf %>% filter_(~Fserno==recv) %>% select_("ID") %>% `[[` (1)
        newf = allf %>% filter_(~Fserno==recv)

        ## dplyr::src for receiver database

        src = sgRecvSrc(recv, dbdir)

        ## sqlite connection

        con = src$con
        dbGetQuery(con, "pragma journal_mode=wal")

        ## existing files in database

        oldf = tbl(src, "files")

        ## grab latest file timestamp for each boot session

        maxOldTS = oldf %>% group_by(monoBN) %>% summarise_(maxOldTS=~max(ts)) %>% collect

        newf = newf %>%

    ## join against existing files
        left_join(oldf, by="name", copy=TRUE) %>%

            ## Mark files for which an existing complete copy is in the database
            ## (note that isDone == NA means the file is not there at all)
            mutate(
                done = is.finite(isDone) & isDone,

                ## Mark compressed version of new files which are present as both
                ## compressed and uncompressed, as the compressed one is incomplete.
                ## Files are sorted by name, so the compressed copy will be marked
                ## as TRUE by duplicated().

                partial = duplicated(name),

                ## Mark uncompressed files which are not longer than the existing version

                nsize = file.info(fullname)[["size"]],
                small = ! is.na(size) & nsize <= size & ! done & ! partial,

                ## Mark files not seen before
                new = is.na(fileID),

                ## Mark files we want to use
                use = ! (done | partial | small),

                ## Assume compressed files are not corrupt
                corrupt = FALSE

            )

        ## get receiver information; if NULL, grab it from the first file

        ## FIXME? is there a cleaner way to do '%>% collect %>% as.XXX' to get a scalar entry from a tbl?

        meta = getMap(src, "meta")

        meta$recvSerno = paste0("SG-", recv)
        meta$recvType = "SG"
        meta$recvModel = if (grepl("BBBK", newf$Fserno[1])) "BBBK" else if (grepl("RPi2", newf$Fserno[1])) "RPi2" else "BBW"

        ## because macAddr has not been supplied in the past, we try grab it
        ## if *any* file provides it, so long as it's for the correct recv

        if (is.null(meta$recvMACAddr)) {
            first = which(! is.na(newf$FmacAddr))
            if (length(first) > 0 && newf$Fserno[first[1]] == meta$serno) {
                meta$macAddr = newf$FmacAddr[first[1]]
            }
        }
        now = as.numeric(Sys.time())
        if (nrow(newf) > 0) {
            for (i in 1:nrow(newf)) {
                if (! newf$use[i])
                    next

                ## grab file contents as bz2-compressed raw vector
                fcon = tryCatch(
                    getFileAsBZ2(newf$fullname[i], newf$Fcomp[i], newf$nsize[i]),
                    error = function(e) NULL
                )

                if (is.null(fcon)) {
                    warning("Skipping unreadable file", newf$fullname[i], "\nPerhaps it is corrupt?")
                    newf$corrupt[i] = TRUE
                    next
                }

                if (newf$new[i]) {
                    ## not yet in database
                    dbGetPreparedQuery(
                        con,
                        "insert into files (name, size, bootnum, monoBN, ts, tscode, tsDB, isDone) values (:name, :size, :bootnum, :monoBN, :ts, :tscode, :tsDB, :isDone)",

                        data.frame(
                            name     = newf$name[i],
                            size     = attr(fcon, "len"),
                            bootnum  = newf$Fbootnum[i],
                            monoBN   = newf$Fbootnum[i],
                            ts       = newf$Fts[i],
                            tscode   = newf$FtsCode[i],
                            tsDB     = now,
                            isDone   = newf$Fextension[i] != "",
                            stringsAsFactors = FALSE
                        )
                    )
                    dbGetPreparedQuery(
                        con,
                        "insert into fileContents (fileID, contents) values (last_insert_rowid(), :contents)",
                        data.frame(contents=I(list(fcon)))
                    )
                } else {
                    dbGetPreparedQuery(
                        con,
                        "update files set size=:size fileID=:fileID ",
                        data.frame(
                            size     = attr(fcon, "len"),
                            fileID   = newf$fileID[i]
                        )
                    )
                    dbGetPreparedQuery(
                        con,
                        "update fileContents set contents=:contents where fileID=:fileID ",
                        data.frame(
                            contents = list(fcon),
                            fileID   = newf$fileID[i]
                        )
                    )
                }
            }
        }
        ## shut down this sqlite connection
        dbGetQuery(con, "pragma journal_mode=delete")
        rm(src)

        ## record results

        allf    [ri, c("use", "new", "done", "corrupt", "small", "partial")] <-
            newf[  , c("use", "new", "done", "corrupt", "small", "partial")]

        ## check for resumability

        minNewTS = allf[ri, ] %>% filter_(~use) %>% group_by(Fbootnum) %>% summarise_(recv=~first(Fserno), minNewTS=~min(Fts)) %>% collect
        if (nrow(minNewTS) > 0) {
            compare = minNewTS %>% left_join (maxOldTS, by=c(Fbootnum="monoBN"))

            resumable = c(resumable, structure(is.na(compare$maxOldTS) | compare$minNewTS >= compare$maxOldTS, names = paste(compare$recv, compare$Fbootnum)))
        }
    }
    return (list(
        info = structure(allf %>%
                         transmute(
                             name = fullname,
                             use = use & ! corrupt,
                             new = new,
                             done = done,
                             corrupt = corrupt,
                             small = small,
                             partial = partial,
                             serno = recv,
                             monoBN = Fbootnum,
                             ts = Fts
                         ), nbadfiles=nbadfiles),
        resumable = resumable))
}
