#' Add a file or folder to the server queue.
#'
#' @param path the full path to the file or directory.
#'
#' @param ... further parameters to the tempfile function; e.g.
#' specifying \code{pattern="URL_"} will cause the file or folder
#' name to begin with "URL_".
#' 
#' After this call, the file or directory will no longer exist at the
#' same location, but will be renamed into the server's incoming
#' directory.  The new name will be unique there, and can include
#' a pattern and fileext specified in \code{...}
#'
#' @return TRUE on success; FALSE otherwise
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @examples
#' ## Not run:
#' enqueue("/tmp/mytmpurlfile", pattern="url_", fileext=".txt")
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}


enqueue = function(path, ...) {
    file.rename(path, tempfile(tmpdir=MOTUS_PATH$QUEUE, ...))
}
