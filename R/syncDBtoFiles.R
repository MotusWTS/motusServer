#' Make sure all files stored internally in a receiver DB are also
#' present in the file_repo.
#'
#' Any file which is either missing from the file repo (ignoring the
#' compression extension) or is present in the DB with longer contents
#' is copied from the DB to the file_repo, with the existing copy
#' getting moved to a backup folder.  The copied-out file is written
#' compressed and so given the .gz extension
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

syncDBtoFiles = function(serno, dbdir=MOTUS_PATH$RECV, repo=MOTUS_PATH$FILE_REPO, bkup=MOTUS_PATH$TRASH) {
    db = getRecvSrc(serno, dbdir=dbdir)
    meta = getMap(db)
    isSG = meta$recvType == "SENSORGNOME"
    if (isSG) {
        dbFiles = tbl(db, "files") %>% collect
        repoFiles = dir(file.path(repo, serno), full.names=TRUE, recursive=TRUE)
        repoFiles = cbind(name=repoFiles, basename=basename(repoFiles), file.info(repoFiles), stringsAsFactors=FALSE)
        dbFiles$repoTxt = match(dbFiles$name, repoFiles$basename)
        dbFiles$repoGz = match(paste0(dbFiles$name, ".gz"), repoFiles$basename)
        dbFiles$status = 2L ## assume file must be added to repo
        for (i in 1:nrow(dbFiles)) {
            dest = NA
            doBkup = FALSE
            j = dbFiles$repoGz[i]
            for (.ii in 1) {
                ## not a loop
                if (! is.na(j)) {
                    len = suppressWarnings(system(paste0("gzip -l ", repoFiles$name[j], " | gawk 'FNR==2{print $2}' 2>/dev/null"), ignore.stderr=TRUE, intern=TRUE))
                    if (isTRUE(as.integer(len) >= dbFiles$size[i])) {
                        dbFiles$status[i] = 0L
                        break
                    } else {
                        doBkup = TRUE
                        dbFiles$status[i] = 1L
                        dest = repoFiles$name[j]
                        break
                    }
                }
                j = dbFiles$repoTxt[i]
                if (! is.na(j)) {
                    if (repoFiles$size[j] >= dbFiles$size[i]) {
                        dbFiles$status[i] = 0L
                        break
                    } else {
                        dbFiles$status[i] = 1L
                        doBkup = TRUE
                        dest = paste0(repoFiles$name[j], ".gz")
                        break
                    }
                }
                ## generate dest path including date folder
                dest = file.path(repo, serno, format(structure(dbFiles$ts[i], class=class(Sys.time())), "%Y-%m-%d"), paste0(dbFiles$name[i], ".gz"))
            }
            if (doBkup) {
                bkupFile = file.path(bkup, serno, repoFiles$basename[j])
                dir.create(dirname(bkupFile), recursive=TRUE, showWarnings=FALSE)
                file.rename(repoFiles$name[j], bkupFile)
            }
            if (! is.na(dest)) {
                fc = dbGetQuery(db$con, sprintf("select t1.fileID, bz2uncompress(t2.contents, t1.size) from files as t1 join fileContents as t2 on t1.fileID=t2.fileID where t1.fileID=%d", dbFiles$fileID[i]))[[2]][[1]]
                dir.create(dirname(dest), recursive=TRUE, showWarnings=FALSE)
                out = gzfile(dest, "wb")
                writeBin(fc, out)
                close(out)
            }
        }
    } else {
        stop("Not yet implemented")
##        files = tbl(db, "DTAfiles") %>% collect
    }
    return(dbFiles[,c("name", "status")])
}
