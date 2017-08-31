#' Make sure all files stored internally in a Sensorgnome receiver DB
#' are also present in the file_repo.
#'
#' Any file which is either missing from the file repo (ignoring the
#' compression extension) or is present in the DB with longer contents
#' is copied from the DB to the file_repo, with the existing copy
#' getting moved to a backup folder.  The copied-out file is written
#' compressed and so given the .gz extension
#'
#' To workaround at least this bug:
#'    https://github.com/jbrzusto/motusServer/issues/213
#' files are matched by (bootnum, timestamp), with a sanity check
#' examining the first 3 lines of any match.
#'
#' @param serno receiver serial number
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{MOTUS_PATH$RECV}
#'
#' @param repo path to folder with existing receiver file repos
#' Default: \code{MOTUS_PATH$FILE_REPO}
#'
#' @param bkup path to folder for storing replaced files as backup.  They will
#' be stored in a folder whose name is the receiver serial number
#' Default: \code{MOTUS_PATH$TRASH}
#'
#' @return a data.frame with these columns:
#' \itemize{
#' \item name - character; bare filename, without compression extension
#' \item status - integer; status of DB file; possible values:
#' \itemize{
#' \item 0: file already in repo and contents there of same size equal or larger than DB contents, so no action taken
#' \item 1: file already in repo but contents there were smaller than DB contents, so file replaced
#' and old copy sent to \code{oldrepo}
#' \item 2: file not in repo, so added to repo
#' }
#' }
#'
#' Returns NULL if no valid data files were found.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgSyncDBtoRepo = function(serno, dbdir=MOTUS_PATH$RECV, repo=MOTUS_PATH$FILE_REPO, bkup=MOTUS_PATH$TRASH) {

    db = getRecvSrc(serno, dbdir=dbdir)
    sql = safeSQL(db$con)
    meta = getMap(db)
    ## two data_frames: fdb = files in database; frp = files in file repo

    fdb = tbl(db, "files") %>% collect
    fdb$tsString = sprintf("%.4f", fdb$ts)
    frp = data_frame(name=dir(file.path(repo, serno), full.names=TRUE, recursive=TRUE))
    frp = frp %>% mutate (basename = basename(name))
    frp = with(frp, cbind(frp, parseFilenames(name, basename, checkDOS=FALSE), file.info(name)))
    frp = frp %>% mutate(tsString = sprintf("%.4f", as.numeric(ts)))

    ## hash values are paste(numeric timestamp, boot number)
    fdb = fdb %>% mutate(hash = paste(tsString, monoBN))
    frp = frp %>% mutate(hash = paste(tsString, bootnum))

    ## due to the bug mentioned in the docs, we need to grab the largest of any DB file record
    ## when grouped by hash
    fdb = fdb %>% arrange (hash, -size) %>% filter (!duplicated(hash))

    ## join on hash; each fdb record will match 0, 1, or 2 frp records (2 in the case of both
    ## .txt and .txt.gz files exisiting in the repo)

    fdb = fdb %>% left_join(frp, by="hash")
    fdb = fdb %>% mutate(status=as.integer(NA)) ## to be filled in below; NA so we can easily tell if any cases missed

    ## group by hash; groups will have usually have size 1, but will have size 2 if both the .txt and .txt.gz
    ## versions of a db file are in the file_repo

    fdb = fdb %>% group_by(hash)

    ## colnames(fdb):
    ##  [1] "fileID"     "name.x"     "size.x"     "bootnum.x"  "monoBN"     "ts.x"       "tscode"     "tsDB"       "isDone"     "motusJobID" "tsString.x" "hash"
    ## [13] "name.y"     "basename"   "prefix"     "serno"      "bootnum.y"  "tsString.y" "tsCode"     "port"       "extension"  "comp"       "ts.y"       "size.y"
    ## [25] "isdir"      "mode"       "mtime"      "ctime"      "atime"      "uid"        "gid"        "uname"      "grname"     "status"

    #' Treat each linked group of files between db and repo
    #'
    #' A file in the db is linked to 0, 1, or 2 files in the repo;
    #' this function receives a tbl of the linked rows and
    #' handles them according to this baroque (rococco?) scheme:
    #'
    #' \code{
    #'       if file not in repo (i.e. is.na(name.y))
    #'           write file to repo (as .gz if done in db, else as .txt)
    #'           status = 2L
    #'       else if done in DB
    #'           if complete compressed file present in repo
    #'              ## this is the typical case
    #'              ## and can be checked quickly (with a tiny probability of error) by:
    #'              4-byte "uncompressed size" tail of .gz file from repo == "size.x"
    #'              status = 0L
    #'           else
    #'              ## repo has an incomplete or no version of the compressed file
    #'              move repo .gz and .txt (if present) file(s) to backup location
    #'              write file to repo (as .gz)
    #'              status = 1L
    #'       else ## not done in DB, but file in repo
    #'           if uncompressed file in repo and size.x <= size.y
    #'              ## repo has a text file and it's bigger than the db size,
    #'              ## so db has nothing to add
    #'              status = 0L
    #'           else if completed compressed file in repo (use gzip -t)
    #'              ## the repo already has a complete .gz file
    #'              status = 0L
    #'           else
    #'              ## whatever is in repo is either not complete (.gz) or smaller than what
    #'              ## db has, so replace with DB version as .txt file
    #'              move repo .txt and .gz file(s) to backup location
    #'              write file to repo (as .txt)
    #'              status = 1L
    #'   }
    #'
    #' @param x tbl of linked records between db and repo
    #'
    #' @param serno character scalar receiver serial number
    #'
    #' @param repo path to file repo
    #'
    #' @param bkup path to file backups
    #'
    #' @return integer status: 0=already in repo and not changed; 1=already in repo and updated; 2=not in repo and saved there

    treatLinkedFiles = function(x) {
        status = as.integer(NA) ## return value; set to NA to validate case coverage
        writeToRepo = ""  ## whether to write db file to repo, and how:  "": don't; "txt" as txt, "gz" as compressed txt
        backupFiles = FALSE ## whether to move existing repo files to backup
        if (is.na(x$name.y[1])) {
            writeToRepo = if (x$isDone) "gz" else "txt"
            status = 2L
        } else if (x$isDone[1]) {
            ## complete compressed file in db
            comp = which(x$comp == ".gz")[1]
            if (! is.na(comp) && x$size.y[comp] >= 20 && uncompressedSize(x$name.y[comp]) == x$size.x[comp]) {
                ## complete compressed file already in repo
                status = 0L
            } else {
                ## complete compressed file not present in repo
                backupFiles = TRUE
                writeToRepo = "gz"
                status = 1L
            }
        } else {
            ## db does not have complete file and file already in repo
            uncomp = which(x$comp == "")[1]
            comp = which(x$comp != "")[1]
            if ((! is.na(uncomp) && x$size.y[uncomp] >= x$size.x[uncomp]) ||
                (! is.na(comp)   && compressedFileDone(x$name.y[comp]))) {
                ## repo has uncompressed file already larger than one in db, or a complete compressed file
                status = 0L
            } else {
                ## repo copy is either not complete (.gz) or smaller than db's copy (.txt)
                backupFiles = TRUE
                writeToRepo = "txt"
                status = 1L
            }
        }
        if (backupFiles) {
            bkup_dir = file.path(bkup, serno)
            dir.create(bkup_dir, recursive=TRUE, showWarnings=FALSE)
            file.rename(x$name.y, file.path(bkup_dir, x$basename))
        }

        if (writeToRepo != "") {
            if (is.na(x$name.x[1])) {
                if (is.na(x$prefix[1])) {
                    ## FIXME: get correct filename; there's no prefix field if file was not found in repo.  But I
                    ## think this situation is rare or even non-existent.
                    stop("Can't generate correct name:  file not in repo, and name field in db is empty")
                }
                fname = paste0(x$prefix[1], '-', x$serno[1],'-', x$bootnum.x[1], '-', tsString, x$tscode[1], '-', x$port[1], x$extension[1])
            } else {
                fname = x$name.x[1]
            }
            data = sql("select bz2uncompress(t2.contents, t1.size) as raw from files as t1 join fileContents as t2 on t1.fileID=t2.fileID where t1.fileID=:fileID",
                       fileID = x$fileID[1])[[1]][[1]]
            if (is.na(data[1]))
                data = raw(0)
            comp = writeToRepo == "gz"
            if (comp)
                fname = paste0(fname, ".gz")
            ts = structure(x$ts.x[1], class=class(Sys.time()))
            tsString = paste0(format(ts, "%Y-%m-%dT%H-%M-%S"), sprintf("%.4f", as.numeric(x$ts.x[1]) %% 1.0))
            ## generate correct destination file from components in db record
            dest = file.path(repo, serno, format(ts, "%Y-%m-%d"), fname)
            dir.create(dirname(dest), recursive=TRUE, mode="0770", showWarnings=FALSE)
            if (comp) {
                con = gzfile(dest, "wb")
                writeBin(data, con)
                close(con)
            } else {
                con = file(dest, "wb")
                writeBin(data, con)
                close(con)
            }
        }
        return(data.frame(status=status))
    }
    rv = fdb %>% do(treatLinkedFiles(.))
    return(data_frame(name=fdb$name.x[!duplicated(fdb$hash)], status=rv$status))
}



#' get size of uncompressed .gz file from 4-byte footer
#'
#' @param gzfile character scalar filename
#'
#' @return the signed integer taken from the last 4 bytes
#' of the file (little-endian).  This only represents the
#' size of the last complete gz stream in the file, and if
#' the file does nto end with a completed gz stream, then
#' the value returned by this function is invalid.
#'
#' i.e. this function's return value is only valid if \code{compressedFileDone(gzfile) == TRUE}

uncompressedSize = function(gzfile) {
    size = 0
    fcon = file(gzfile, "rb")
    tryCatch({
        seek(fcon, -4, "end")
        size = readBin(fcon, integer(), size=4)
    }, error = function(e){})
    close(fcon)
    return(size)
}

#' is a .gz file actually finished?
#'
#' @param gzfile character scalar filename
#'
#' @return TRUE if the file exists and is a complete (valid) .gz file;
#' FALSE otherwise

compressedFileDone = function(gzfile) {
    isTRUE(0 == attr(safeSys("gzip", "-t", gzfile, minErrorCode=1000), "exitCode"))
}
