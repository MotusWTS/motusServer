#' does a job have a folder in the filesystem?
#'
#' @param j Twig object representing the job
#'
#' @return TRUE if and only if the job 'should' have a folder in the
#'     filesystem.  This is indicated by a non-null value for the
#'     job's \code{path} column in the Copse database, which translates
#'     into a non-NA value in R.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

jobHasFolder = function(j) {
    return (! is.na(j$path))
}
