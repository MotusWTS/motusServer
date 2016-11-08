#' handle a set of files of unknown type
#'
#' Called by \code{\link{processServer}}.  Files are
#' retained, and the sender is emailed a list of the files.
#'
#' @param j the job
#'
#' @return  TRUE;
#'
#' @seealso \code{\link{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleUnknownFiles = function(j) {
    tj = topJob(j)

    ## if this email had valid authorization
    if (tj$valid) {
        email(tj$replyTo[1], paste0("motus job ", tj, ": some files you sent could not be processed"),
              paste0("I don't know how to handle the following files from your transfer:\n\n",
                     paste0("   ", dir(j$path, recursive=TRUE, full.names=FALSE), collapse="\n"),
                     "\n\nThese files have been retained on our server."
                     )
              )
        return(TRUE)
    }
    return(FALSE)
}