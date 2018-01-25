#' Merge a batch of raw SG files with their receiver database(s).
#'
#' Determines which files are redundant, new, or partially new.  Does
#' *not* run the tag finder.
#'
#' Any new content from files is merged into the files and fileContents
#' tables of the receiver DBs.
#'
#' Files are disposed of like so:
#' \itemize{
#' \item any files which are symlinks are deleted
#' after merging their target's contents; i.e. the symlink is deleted,
#' not the file it points to.
#' \item files whose path has \code{MOTUS_PATH$FILE_REPO} as a prefix are left as-is
#' \item files whose path does not have \code{MOTUS_PATH$FILE_REPO} as a prefix, and which
#' either are new or have new content are moved to \code{MOTUS_PATH$FILE_REPO/serno/YYYY-MM-DD}
#' \item remaining files are moved to \code{MOTUS_PATH$TRASH}
#' }
#'
#' @param files either a character vector of full paths to files, or
#'     the full path to a directory, which will be searched
#'     recursively for raw sensorgnome data files.
#'
#' @param j job, whose ID will be recorded with records of new / changed files.
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{MOTUS_PATH$RECV}
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

sgMergeFiles = function(files, j, dbdir = MOTUS_PATH$RECV) {
    if (! isTRUE(is.character(files) && all(file.exists(files))))
        stop("invalid or non-existent input files specified")
    if (file.info(files[1])$isdir) {
        ff = dir(files, recursive=TRUE, full.names=TRUE)
    }

    if (length(ff) == 0)
        return(NULL)

    ## handle files with duplicate names *within* the archive.
    ## see https://github.com/jbrzusto/motusServer/issues/324
    ## Mostly, this is just due to users inadvertently pasting
    ## copies of folders inside other folders before creating
    ## the archive.
    ## But in case it is due to multiple downloads from the receiver
    ## being combined into a single upload, we always pick the largest
    ## copy from any set of files with the same name. This covers the
    ## situation where a file might have grown between the two receiver
    ## downloads, since we want the larger file in this case.

    sizes = file.size(ff)

    ## Get indexes of files in decreasing order by size
    ii = order(sizes, decreasing=TRUE)

    ## Sort files in increasing order by basename, once they are
    ## already sorted in decreasing order by size.  Because the 2nd
    ## sort is stable, files with identical basenames will appear
    ## in decreasing order by size.

    bn = basename(ff)[ii]
    ff = ff[ii]
    ii = order(bn)
    bn = bn[ii]
    ff = ff[ii]

    ## drop duplicates
    keep = which(! duplicated(bn))
    if (length(keep) < length(bn)) {
        ff = ff[keep]
        bn = bn[keep]
        jobLog(j, "This upload contains two or more files with identical names.  For each set of files with identical names, I will use only the largest.")
    }

    ## clean up the basename, in case there are wonky characters; we
    ## don't do this to "fullname", to maintain our ability to refer
    ## to the files from the filesystem.

    allf = data_frame(
        ID       = seq_len(length(ff)),
        fullname = ff,
        basename = bn %>% iconv(to="UTF-8", sub="byte")
    )

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
    ## - if F is in oldf and isDone is TRUE, we do nothing, as
    ##   complete file is already present
    ##
    ## - if F is compressed F and valid, it must be complete, and so
    ##   we copy it to oldf and set isDone to TRUE
    ##
    ## - if F is compressed and not valid, we ignore it
    ##
    ## - if F is uncompressed and either not already in, or longer
    ##   than the existing version in the DB, copy it to the DB

    ## parse filenames into components
    pfc = parseFilenames(allf$fullname, allf$basename)

    ## modify component names to avoid collisions with names in database 'files' table
    names(pfc) = paste0("F", names(pfc))

    ## bind parsed filename components
    allf = allf %>% bind_cols(pfc) %>% as.tbl  ## make sure it's a tbl; bind_cols wasn't behaving as doc'd

    ## fix case of components and add status fields

    allf = allf %>%
        mutate (
            Fserno     = toupper(Fserno),
            FtsCode    = toupper(FtsCode),
            Fport      = tolower(Fport),
            Fextension = tolower(Fextension),
            Fcomp      = tolower(Fcomp),
            Fname      = sub("\\.gz$", "", allf$basename),
            iname     = tolower(Fname),
            done      = FALSE,
            partial   = FALSE,
            nsize     = NA,
            small     = FALSE,
            new       = FALSE,
            use       = FALSE,
            corrupt   = FALSE
        )

    ## work with files from each receiver separately
    recvs = allf %>% select_("Fserno") %>% distinct_ %>% `[[` (1)

    nbadfiles = nrow(allf %>% filter_(~is.na(Fserno)))

    resumable = logical()

    for (recv in recvs) {
        if (is.na(recv))
            next

        ## lock the receiver

        lockSymbol(recv)

        ## make sure we unlock the receiver DB when this function exits, even on error
        ## NB: the runMotusProcessServer script also drops any locks held by a given
        ## processServer after the latter exits.

        on.exit(lockSymbol(recv, lock=FALSE))

        ## get the row indexes of files from this receiver among the full set of files

        ri = allf %>% filter_(~Fserno==recv) %>% select_("ID") %>% `[[` (1)

        ## subset the files from this receiver
        newf = allf %>% filter_(~Fserno==recv)

        ## dplyr::src for receiver database

        src = getRecvSrc(recv, dbdir)

        ## sqlite connection

        con = src$con
        dbExecute(con, "pragma journal_mode=wal")

        ## existing files in database

        oldf = tbl(src, "files") %>% collect(n=Inf) %>% mutate (iname = tolower(name))


        ## grab latest file timestamp for each boot session

        maxOldTS = oldf %>% group_by(monoBN) %>% summarise_(maxOldTS=~max(ts)) %>% collect

        newf = newf %>%

    ## join against existing files
        left_join(oldf, by="iname", copy=TRUE) %>%

            ## Mark files for which an existing complete copy is in the database
            ## (note that isDone == NA means the file is not there at all)
            mutate(
                done = is.finite(isDone) & isDone,

                ## See which files are incomplete .gz files; (only
                ## test .gz files we don't already have in full; i.e. do test
                ## number 4 only on files where done is FALSE)

                partial = testFile(fullname, tests=as.list(4 * ! done)) > 0,

                ## Mark uncompressed files which are not longer than the existing version

                nsize = file.size(fullname),
                small = (Fcomp == "") & (! is.na(size) & nsize <= size),

                ## Mark files not seen before
                new = is.na(fileID),

                ## Mark files we want to use
                use = ! (done | partial | small),

                ## Assume compressed files are not corrupt
                corrupt = FALSE

            )

        ## get receiver information; if NULL, grab it from the first file

        ## FIXME? is there a cleaner way to do '%>% collect %>% as.XXX' to get a scalar entry from a tbl?

        meta = getMap(src)
        now = as.numeric(Sys.time())
        if (nrow(newf) > 0) {
            for (i in seq_len(nrow(newf))) {
                if (! newf$use[i])
                    next

                ## calculate length of uncompressed file contents

                if (newf$Fcomp[i] == "") {
                    ## just the file size, for a text file
                    len = newf$nsize[i]
                } else {
                    ## as much as zcat can get, for a .gz file
                    len = as.integer(safeSys("zcat", nq1="-q", newf$fullname[i], nq2="2>/dev/null | wc -c"))

                    ## check whether we have also processed the uncompressed version of this file,
                    ## which would have been the previous file, given the alphabetical sorting (".txt" < ".txt.gz")
                    if (i > 1 && newf$Fname[i-1] == newf$Fname[i]) {
                        ## we only keep the compressed version if its uncompressed contents are at least as
                        ## large as those of the compressed version
                        if (len < newf$nsize[i - 1])
                            next
                        ## mark this file as not really new, to get the correct query below
                        newf$new[i] = FALSE
                    }
                }

                if (newf$new[i]) {
                    ## not yet in database
                    dbGetPreparedQuery(
                        con,
                        "insert into files (name, size, bootnum, monoBN, ts, tscode, tsDB, isDone, motusJobID) values (:name, :size, :bootnum, :monoBN, :ts, :tscode, :tsDB, :isDone, :motusJobID)",

                        data.frame(
                            name             = newf$Fname[i],
                            size             = len,
                            bootnum          = newf$Fbootnum[i],
                            monoBN           = newf$Fbootnum[i],
                            ts               = newf$Fts[i],
                            tscode           = newf$FtsCode[i],
                            tsDB             = now,
                            isDone           = newf$Fcomp[i]==".gz",  ## incomplete compressed files are dropped above
                            motusJobID       = as.integer(j),
                            stringsAsFactors = FALSE
                        )
                    )
                } else {
                    dbGetPreparedQuery(
                        con,
                        "update files set size=:size, isDone=:isDone, motusJobID=:motusJobID where fileID=:fileID ",
                        data.frame(
                            size       = len,
                            isDone     = newf$Fcomp[i] == ".gz",  ## incomplete compressed files are dropped above
                            motusJobID = as.integer(j),
                            fileID     = newf$fileID[i]
                        )
                    )
                }
            }
        }
        ## shut down this sqlite connection
        dbGetQuery(con, "pragma journal_mode=delete")
        closeRecvSrc(src)
        rm(src, meta)

        ## record results

        allf    [ri, c("use", "new", "done", "corrupt", "small", "partial")] <-
            newf[  , c("use", "new", "done", "corrupt", "small", "partial")]

        ## check for resumability

        minNewTS = allf[ri, ] %>% filter_(~use) %>% group_by(Fbootnum) %>% summarise_(recv=~first(Fserno), minNewTS=~min(Fts)) %>% collect
        if (nrow(minNewTS) > 0) {
            compare = minNewTS %>% left_join (maxOldTS, by=c(Fbootnum="monoBN"))

            resumable = c(resumable, structure((! is.na(compare$maxOldTS)) & compare$minNewTS >= compare$maxOldTS, names = paste(compare$recv, compare$Fbootnum)))
        }
        lockSymbol(recv, lock=FALSE)
    }

    ## skip files having MOTUS_PATH$FILE_REPO as a prefix
    ff = ff[MOTUS_PATH$FILE_REPO != substr(ff, 1, nchar(MOTUS_PATH$FILE_REPO))]

    ## save any files to be used in the file repo
    reallyUse = allf$use & ! allf$corrupt

    ## which files are really just symlinks
    link = Sys.readlink(ff)
    isLink = !( is.na(link) | link == "")
    keep = reallyUse & !isLink
    useFiles = ff[keep]
    dirsNeeded = unique(file.path(MOTUS_PATH$FILE_REPO, allf$Fserno[keep], format(allf$Fts[keep], "%Y-%m-%d")))
    for( d in dirsNeeded)
        dir.create(d, showWarnings=FALSE, recursive=TRUE)

    safeFileRename(useFiles, file.path(MOTUS_PATH$FILE_REPO, allf$Fserno[keep], format(allf$Fts[keep], "%Y-%m-%d"), basename(useFiles)))

    ## remove files which are just symlinks
    file.remove(ff[isLink])

    ## remove remaining files
    toTrash(ff[!isLink & !keep])

    return (list(
        info = structure(allf %>%
                         transmute(
                             name = fullname,
                             use = reallyUse,
                             new = new,
                             done = done,
                             corrupt = corrupt,
                             small = small,
                             partial = partial,
                             serno = Fserno,
                             monoBN = Fbootnum,
                             ts = Fts
                         ), nbadfiles=nbadfiles),
        resumable = resumable))
}
