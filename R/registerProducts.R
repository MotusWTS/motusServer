#' register product files for a receiver
#'
#' @details Records the products in the job database and creates a symlink
#' to it from the appropriate download folder.
#'
#' @param j the job
#' @param path character vector; locations of the product file
#' @param serno serial number of receiver these products' data come from;
#' default: j$serno
#' @param projectID ID of project that owns the product(s)
#' @param isTesting are these test products?  Default: FALSE
#'
#' @return TRUE
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

registerProducts = function(j, path, serno=j$serno, projectID, isTesting = FALSE) {
    targDir = getProjDir(projectID, isTesting)
    file.symlink(path, targDir)
    url = getDownloadURL(projectID, isTesting)
    jobProduced(j, file.path(url, basename(path)), projectID, serno)
    return (TRUE)
}
