#' Add a file or folder to the server queue.
#'
#' @param path the full path to the file or directory.
#'
#' @param part1 if present, a string to add to the name of the
#' new path.
#'
#' @param ... if present, additional strings to add to the name
#' of the new path.
#'
#' @details Items specified in \code{part1} and \code{...} are appended
#' to the path, separated by '_' (underscore).
#'
#' After this call, the file or directory will no longer exist at the
#' same location, but will be moved into the server's incoming
#' directory.  Also, the path to the item's new location will be appended
#' to the global variable MOTUS_QUEUE.
#'
#' @return the new value of MOTUS_QUEUE (invisibly).
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @examples
#' ## Not run:
#' enqueue("/tmp/mytmpurlfile")
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}


enqueue = function(path, part1, ...) {
    if (missing(part1)) {
        newName = file.path(MOTUS_PATH$QUEUE, basename(path))
    } else {
        newName = makeQueuePath(part1, ..., isdir=file.info(path)$isdir, create=FALSE)
    }
    file.rename(path, newName)

    ## add to the internal representation of the queue, so server() can see it.
    MOTUS_QUEUE <<- c(MOTUS_QUEUE, newName)
}
