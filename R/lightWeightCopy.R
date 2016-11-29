#' Make a light-weight recursive copy of a folder.
#'
#' This uses hardlinks wherever possible, so that file
#' data are not copied, but falls back to normal copy where
#' necessary.
#'
#' @param src character vector; paths to source files / folders
#'
#' @param dst character scalar; path to target folder
#'
#' @return TRUE on success, FALSE otherwise.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

lightWeightCopy = function(src, dst) {
    ## try with hard-links first
    rv = safeSys("cp", "--recursive", "--link", src, dst, minErrorCode=10000)
    if (attr(rv, "exitCode") == 0)
        return(TRUE)

    ## fallback to normal copying
    rv = safeSys("cp", "--recursive", src, dst, minErrorCode=10000)
    return (attr(rv, "exitCode") == 0)
}
