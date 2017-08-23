#' Make sure all files stored internally in a receiver DB are also
#' present in the file_repo.
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

syncDBtoRepo = function(serno, dbdir=MOTUS_PATH$RECV, repo=MOTUS_PATH$FILE_REPO, bkup=MOTUS_PATH$TRASH) {
    isSG = grepl("^SG-", serno, perl=TRUE)
    if (isSG) {
        sgSyncDBtoRepo(serno, dbdir, repo, bkup)
    } else {
        ltSyncDBtoRepo(serno, dbdir, repo, bkup)
    }
}
