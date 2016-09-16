#' Get listing of full paths to items in folder(s), sorted by choice of
#' item from file.info
#'
#' @param paths set of folders to list
#'
#' @param sortBy character vector; names of one or more columns
#'     returned by file.info:
#'
#' \itemize{
#'    \item size
#'    \item isdir
#'    \item mode
#'    \item mtime
#'    \item ctime
#'    \item atime
#'    \item uid
#'    \item gid
#'    \item uname
#'    \item grname
#' }
#' or these additional names:
#' \itemize{
#'    \item name - filename, without directory
#'    \item path - full path to file
#' }
#'
#' @param recursive boolean; should all items from subfolders also be listed?
#'
#' @return a character vector of paths to files, sorted by the specified property.
#' The sorting happens *across* folders, rather than within them.
#'
#' @seealso \link{\code{dir}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

dirSortedBy = function(paths, sortBy = "ctime", recursive=FALSE) {
    f = dir(paths, recursive=recursive, full.names=TRUE)
    info = cbind(path=f, name=basename(f), file.info(f))
    f[do.call("order", info[, sortBy, drop=FALSE])]
}
