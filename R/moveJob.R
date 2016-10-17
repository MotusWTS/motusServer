#' move a job from one folder to another
#'
#' Retain the old path to the job, in case of interruption
#' between recording the new path and moving the folder.
#' Also, move all jobs which have this job as an ancestor,
#' adjusting their \code{$path} items appropriately
#'
#' @param job Twig object representing the job.
#'
#' @param dest path to new folder where the job's folder will become
#' a subfolder.
#'
#' @return TRUE on success; FALSE if the job's folder could not be moved
#'
#' @export
#'
#' @seealso \link{\code{Copse}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

moveJob = function(job, dest) {
    if (! file.exists(dest) && ! dir.create(dest, recursive=TRUE, mode=MOTUS_DEFAULT_FILEMODE, showWarnings=FALSE))
        stop("unable to create destination folder: ", dest)
    old = job$path
    new = file.path(dest, basename(job$path))
    s = stump(job)
    C = copse(job)
    ids = query(C, paste0("select id from ", C$table, " where stump =", s, " and path glob '", old, "*'"))[[1]]
    for (id in ids) {
        C[[id]]$oldpath = C[[id]]$path
        C[[id]]$path = sub(old, new, C[[id]]$path, fixed=TRUE)
    }

    if(isTRUE(file.rename(old, new)))
        return(TRUE)
    return(FALSE)
}
