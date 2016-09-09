#' wait for new data files to arrive, then process them
#'
#' Watch the \code{incoming} directory and when a file or folder is
#' written or moved to it, call a sequence of handlers until one of
#' them is successful in processing the item.  Handlers are meant to
#' perform small, self-contained tasks, such as unpacking a compressed
#' archive, parsing an email for downloadable links, updating a
#' receiver database with new files, etc.  This helps limit the effect
#' of failure of one task.  Moreover, we try to ensure that files are
#' left in places where they will automatically be retried if this
#' server function has to be restarted, or can be dealt with manually.
#'
#' Files or folders already in the watched directory are processed
#' before any new ones, on the assumption that a previous call to this
#' function was interrupted.
#'
#' @param handlers list of handlers to be called when a new file or
#'     folder is added to the incoming directory.  Each handler is a
#'     function that takes these parameters:
#'
#' \itemize{
#'
#' \item path: the full path to the new file or directory
#'
#' \item isdir: boolean; TRUE iff the path is a directory
#'
#' }
#'
#' and returns TRUE iff the handler succeeded in processing the item.
#'
#' Handlers are called for each file or folder already in the watch
#' directory, and then for each file or folder created in, moved
#' into, or linked to from that directory. Successful handlers will
#' typically move some or all of the files in \code{path} to another
#' location.
#'
#' The file or folder at \code{path} will be deleted if any handler
#' returns TRUE.
#'
#' The default value of \code{handlers} is:
#' \code{
#' list(
#'    handleEmail,
#'    handleDownloadableLink,
#'    handleArchive,
#'    handleDTAs,
#'    handleSGs,
#'    handleOneSG,
#'    handleLogs,
#'    handlePath
#' )
#' }
#'
#' @return This function does not return; it is meant for use in an R
#'     script run in the background.
#'
#' @note If a directory is added by creating a symlink to it in the
#'     \code{incoming} directory, ownership of files in the directory
#'     remains with the files' creator, and this function will not
#'     delete them.  Otherwise, ownership is assumed by this function,
#'     and files are deleted if any handler returns TRUE.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

server = function(handlers) {
    if (missing(handlers))
        handlers =  list(
            handleEmail,
            handleDownloadableLink,
            handleArchive,
            handleDTAs,
            handleSGs,
            handleOneSG,
            handleLogs,
            handlePath
        )

    ## get names of handler functions
    handlerNames = as.character(substitute(handlers))[-1]

    ## sanity check for handlers
    for (h in handlers)
        if (! is.function(h) || ! sort(names(formals(h))) == c("isdir", "path"))
            stop("Handler must be a function with formals 'path' and 'isdir'")

    ensureServerDirs()

    ## launch inotifywait to report copying into, moving into, and
    ## link creation in the spool directory; report events and
    ## filenames.  Everything after the first colon is part of the
    ## path to the file

    evtCon = pipe(
        paste("inotifywait -q -m -e close_write -e moved_to -e create --format %e:%f", MOTUS_PATH$QUEUE),
        "r")

    ## initialize file queue with list of files in watch directory.
    ## Some of these might be created after starting evtCon but
    ## before calling dir(), so we consume any events for these files
    ## without adding them to the queue.

    queue = dir(MOTUS_PATH$QUEUE)

    motusLog("Server started")

    repeat {
        f = readLines(evtCon, n=1)
        f = sub("^[^:]*:", "", f)
        if (length(f) == 0)
            next
        if (! f %in% queue)
            break
    }

    queue = c(queue, f)

    repeat {
        ## process the queue; it will typically have only 1 element
        while (length(queue) > 0) {
            motusLog("Handling event %s", queue[1])
            p = file.path(MOTUS_PATH$QUEUE, queue[1])
            isdir = file.info(p)$isdir
            handled = FALSE
            for (i in seq(along=handlers)) {
                h = handlers[[i]]
                hname = handlerNames[i]
                tryCatch(
                {
                    handled <- h(path=p, isdir=isdir)
                    if (isTRUE(handled)) {
                        unlink(p, recursive=TRUE)
                        motusLog("Handled by %s", hname)
                    }
                }, error = function(e) {
                    motusLog("Exception while running handler %s: %s", hname, e)
                })
                if (handled)
                    break
            }
            ## if not handled, save the file or folder in the manual handling folder
            if (! handled)
                archivePath(p, MOTUS_PATH$MANUAL)

            ## drop file/dir from queue
            queue = queue[-1]
        }
        ## wait for a new file/dir
        f = readLines(evtCon, n=1)
        f = sub("^[^:]*:", "", f)
        queue = f
    }
}
