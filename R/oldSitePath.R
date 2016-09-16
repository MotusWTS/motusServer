#' get the path to an old-style sensorgnome site.
#'
#' Called by \code{\link{server}} for a file or folder added
#' to the queue.
#'
#' @param year integer; year of receiver deployment
#'
#' @param proj character scalar; project short name
#'
#' @param site character scalar; site short name
#'
#' @return character vector giving path to each site in the old '/SG/' hierarchy.
#' There is one entry for each row of \code{paste0(year, proj, site)}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

oldSitePath = function(year, proj, site) {
    paste("/SG", as.integer(year), proj, site, sep="/")
}
