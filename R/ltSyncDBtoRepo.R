#' Make sure all files stored internally in a Lotek receiver DB
#' are also present in the file_repo.
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

ltSyncDBtoRepo = function(serno, dbdir=MOTUS_PATH$RECV, repo=MOTUS_PATH$FILE_REPO, bkup=MOTUS_PATH$TRASH) {

    db = getRecvSrc(serno, dbdir=dbdir)
    sql = safeSQL(db$con)
    meta = getMap(db)
    ## two data_frames: fdb = files in database; frp = files in file repo

    fdb = tbl(db, "DTAfiles") %>% collect
    if (nrow(fdb) == 0)
        return(NULL)
    recvrpdir = file.path(repo, serno)
    if (! file.exists(recvrpdir))
        dir.create(recvrpdir)
    frp = data_frame(name=dir(recvrpdir, full.names=TRUE, recursive=TRUE))
    frp = frp %>% mutate (basename = basename(name))
    frp = cbind(frp, file.info(frp$name))
    frp$hash = sapply(frp$name, function(x) digest::digest(x, file=TRUE, "sha512"))
    if (nrow(frp) == 0)
        frp$hash = character(0)
    fdb$status = as.integer(NA) ## to be filled in below; NA so we can easily tell if any cases missed

    ## join on hash

    fj = fdb %>% left_join(frp, by="hash")

    ## fj columns
    ## [1] "fileID"     "name.x"     "size.x"     "tsBegin"    "tsEnd"      "tsDB"       "hash"       "contents"   "motusJobID" "name.y"     "basename"   "size.y"
    ## [13] "isdir"      "mode"       "mtime"      "ctime"      "atime"      "uid"        "gid"        "uname"      "grname"     "status"

    if (nrow(fj) > nrow(fdb)) {
        warning("Duplicate (by hash) files present in repo; using first of each set")
        fj = fj[!duplicated(fj$hash),]
    }

    ## any files that succeeded in the join are already in the repo
    good = ! is.na(fj$name.y)
    fdb$status[good] = 0L

    ## join on name
    fj = fdb %>% left_join(frp, by=c(name="basename"))

    if (nrow(fj) > nrow(fdb))
        stop("Duplicate (by name) files present")

    if (any(!is.na(fj$name.y) & fj$size.x == fj$size.y & fj$hash.x != fj$hash.y))
        stop("Some files with same name already in repo and with same size but unequal hash")

    ## files already in repo, but with larger size
    good2 = !is.na(fj$name.y) & fj$size.x < fj$size.y
    fdb$status[good2] = 0L

    ## check for files in repo but smaller
    need = !is.na(fj$name.y) & fj$size.x > fj$size.y
    if (any(need)) {
        dest = file.path(repo, serno)
        bkup_dest = file.path(bkup, serno)
        dir.create(dest, recursive=TRUE, showWarnings=FALSE)
        dir.create(bkup_dest, recursive=TRUE, showWarnings=FALSE)
        for (i in which(need)) {
            data = sql("select bz2uncompress(contents, size) as raw from DTAfiles where fileID=:fileID",
                       fileID = fdb$fileID[i])[[1]][[1]]
            file.rename(fj$name.y[i], file.path(bkup_dest, fj$name[i]))
            con = file(file.path(dest, fj$name[i]), "wb")
            writeBin(data, con)
            close(con)
        }
        fdb$status[need] = 1L
    }

    ## check for files not in repo
    need = is.na(fj$name.y)
    if (any(need)) {
        dest = file.path(repo, serno)
        dir.create(dest, recursive=TRUE, showWarnings=FALSE)
        for (i in which(need)) {
            data = sql("select bz2uncompress(contents, size) as raw from DTAfiles where fileID=:fileID",
                       fileID = fdb$fileID[i])[[1]][[1]]
            con = file(file.path(dest, fj$name[i]), "wb")
            writeBin(data, con)
            close(con)
        }
        fdb$status[need] = 2L
    }
    return(fdb[,c("name", "status")])
}
