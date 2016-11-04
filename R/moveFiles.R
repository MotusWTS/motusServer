#' Move files/folders to a folder
#'
#' @param src character vector; paths to source files / folders
#'
#' @param dst character scalar; path to target folder
#'
#' @return a boolean vector of the same length as \code{src}, with
#'     TRUE entries corresponding to files/folders moved successfully.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

moveFiles = function(src, dst) {
    file.rename(src, file.path(dst, basename(src)))
}
