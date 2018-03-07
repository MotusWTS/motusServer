#' report and maybe record what a job produced
#'
#' Most jobs generate or modify files that the user can access via URL.
#' This function returns a vector of product URLs, after adding any new
#' ones specified.
#'
#' @param j job integer number.  If not a topjob, its topjob is used instead.
#' @param u character vector of job product URLS.  Can be missing.
#' @param projectID integer motus project ID that owns product(s) being recorded
#' @param serno [optional] character vector of receiver serial number associated with each product being recorded
#'
#' @return The character vector of job product URLs, after adding any specified
#' by \code{u}.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

jobProduced = function(j, u, projectID=NA, serno=NA) {
    tj = topJob(Jobs[[j]])
    p = tj$products_
    if (is.null(p))
        p = character(0)
    if (! missing(u)) {
        if (! is.character(u))
            stop("u must be a character vector")
        u = setdiff(u, p)
        if (length(u) > 0) {
            tj$products_ = c(p, u)
            for (i in seq(along=u))
                ServerDB("insert into products (jobID, url, projectID, serno) values (:jobID, :url, :projectID, :serno)",
                             jobID = tj,
                             url = u[i],
                             projectID = projectID,
                             serno = serno)
        }
    }
    return(p)
}
