#' Check whether the top job of which a job is a subjob is done;
#' i.e. whether all subjobs completed, whether successfully or not.
#'
#' @param j the job
#'
#' @return TRUE iff all other jobs having the same stump have \code{done != 0}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

isTopJobDone = function(j) {
    if (!inherits(j, "Twig"))
        j = Jobs[[j]]
    return (length(Jobs[stump==R(stump(j)) && done == 0]) == 0)
}
