#' move a subjob to a new parent job
#'
#' Also, if the job has a folder, then the job's folder is moved from
#' its current location to the the folder of the new parent.
#'
#' @param j Twig object representing the subjob.
#'
#' @param p Twig object representing the new parent.  If
#'
#' @return TRUE on success; FALSE if the job's folder could not be moved
#'
#' Note: this function can not reparent a top job.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

reparentJob = function(j, p) {
    if (is.null(parent(j)))
        stop("can only use reparentJob() on a subjob")
    path = jobPath(j)
    j$oldpath = path ## record the previous full path
    parent(j) = p
    if (jobHasFolder(j))
        return(moveFiles(path, jobPath(p)))
    else
        return(TRUE)
}
