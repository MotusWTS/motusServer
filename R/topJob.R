#' return the top-level job for which the given job is a subjob
#'
#' @param j the job
#'
#' @return the toplevel ancestor of \code{j}; this might be
#' \code{j} itself.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

topJob = function(j) {
    stump(j)
}
