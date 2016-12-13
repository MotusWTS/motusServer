#' is this a top-level job?
#'
#' @param j Twig object representing the job
#'
#' @return TRUE if and only if the job does not have a parent job.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

isTopJob = function(j) {
    is.null(parent(j))
}
