#' Enqueue a command that doesn't require a file or folder.
#'
#' @param name
#'     command name; e.g. 'SGnew'
#'
#' @param ... additional parameters for the command
#'
#' @details  An empty file is created with the name \code{paste0(TIMESTAMP, '_', paste0(c(name, ...), collapse='_'))}.  This file is moved to the processing queue.
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
                     paste0(c(format(Sys.time(), MOTUS_TIMESTAMP_FORMAT),
                              '_', paste0( list(name, ...), collapse='_')))
                     )
    f = file(path, "wb")
    close(f)
    file.rename(path, file.path(MOTUS_PATH$QUEUE, basename(path)))
}
