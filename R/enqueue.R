#' Add a file or folder to the server queue.
#'
#' @param path the full path to the new file or directory
#'
#' After this call, the file or directory will no longer exist at the
#' same location.
#'
#' @return TRUE on success; FALSE otherwise
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}


enqueue = function(path) {
    file.rename(path, tempfile(tmpdir=MOTUS_PATH$QUEUE))
}
