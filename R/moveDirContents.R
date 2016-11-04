#' Move the contents of a directory to another directory.
#'
#' @details
#'
#' All files and sub-directories are moved.
#'
#' @param src character scalar; path to source directory
#'
#' @param dst path to target folder
#'
#' @return a boolean vector of the same length as
#' \code{list.files(src, all.files=TRUE, recursive=FALSE, no..=TRUE, include.dirs=TRUE)}, with TRUE
#' entries corresponding to files moved successfully.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

moveDirContents = function(src, dst) {
    moveFiles(list.files(src, all.files=TRUE, recursive=FALSE, no..=TRUE, include.dirs=TRUE, full.names=TRUE), dst)
}
