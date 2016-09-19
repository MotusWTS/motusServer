#' Add a file or folder to the external server queue.
#'
#' @param path the full path to the file or directory.
#'
#' After this call, the file or directory will no longer exist at the
#' same location, but will be moved into the server's incoming
#' directory. 
#'
#' @return TRUE on success; FALSE otherwise
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @examples
#' ## Not run:
#' toIncoming("/tmp/mytmpurlfile")
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

toIncoming = function(path) {
    file.rename(path, file.path(MOTUS_PATH$INCOMING, basename(path)))
}
