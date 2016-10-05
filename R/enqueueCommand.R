#' Enqueue a command that doesn't require a file or folder.
#'
#' @param name
#'     command name; e.g. 'SGnew'
#'
#' @param ... additional parameters for the command
#'
#' @details  An empty file is created with the name \code{paste0(TIMESTAMP, MOTUS_QUEUE_SEP, paste0(c(name, ...), collapse=MOTUS_QUEUE_SEP))}.  This file is moved to the processing queue.
#'
#' @return TRUE on success.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

enqueueCommand = function( name, ...) {
    if (missing(name))
        stop("Need command name")

    path = file.path(MOTUS_PATH$TMP,
                     paste0(format(Sys.time(), MOTUS_TIMESTAMP_FORMAT),
                              MOTUS_QUEUE_SEP, paste0( list(name, ...), collapse=MOTUS_QUEUE_SEP))
                     )
    f = file(path, "wb")
    close(f)
    file.rename(path, file.path(MOTUS_PATH$QUEUE, basename(path)))
}
