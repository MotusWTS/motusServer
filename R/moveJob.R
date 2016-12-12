#' move a top job to a new folder
#'
#' Retain the old path to the job, in case of interruption
#' between recording the new path and moving the folder.
#'
#' @param j Twig object representing the job.
#'
#' @param dest path to new folder where the job's folder will become
#' a subfolder.
#'
#' @return TRUE on success; FALSE if the job's folder could not be moved
#'
#' Note: this function can only move a top job.  To move subjobs to different
#' parents, use \link{\code{reparentJob()}}
#'
#' @export
#'
#' @seealso \link{\code{Copse}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

moveJob = function(j, dest) {
    if (! is.null(parent(j)))
        stop("can only use moveJob() on a top-level job")
    old = jobPath(j)
    j$oldpath = old ## save the old path
    j$path = dest
    if (! file.exists(dest) && ! dir.create(dest, recursive=TRUE, mode=MOTUS_DEFAULT_FILEMODE, showWarnings=FALSE))
        stop("unable to create destination folder: ", dest)
    new = file.path(dest, basename(old))
    if(isTRUE(file.rename(old, new)))
        return(TRUE)
    return(FALSE)
}
