#' report and maybe record what a job produced
#'
#' Most jobs generate or modify files that the user can access via URL.
#' This function returns a vector of product URLs, after adding any new
#' ones specified.
#'
#' @param j job integer number.  If not a topjob, its topjob is used instead.
#' @param u character vector of job product URLS.  Can be missing.
#'
#' @return The character vector of job product URLs, after adding any specified
#' by \code{u}.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

jobProduced = function(j, u) {
    tj = topJob(Jobs[[j]])
    p = tj$products_
    if (is.null(p))
        p = character(0)
    if (! missing(u)) {
        if (! is.character(u))
            stop("u must be a character vector")
        p = unique(c(p, u))
        tj$products_ = p
    }
    return(p)
}
