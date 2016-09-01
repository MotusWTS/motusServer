#' wait for new data files to arrive, then process them
#'
#' This function watches the /sgm/incoming directory and when a file
#' or folder is written to it, carries out the specified action.
#' Files or folders already in the watched directory are processed
#' before any new ones, on the assumption that a previous call to this
#' function was interrupted.
#'
#' The function does not return; it is meant for use in an R script
#' run in the background.
#'
#' @param handlers list of handlers to be called when a new file or
#'     folder is added to \code{/sgm/incoming}.  Each handler is a
#'     function that takes these paramters:
#'
#' \itemize{
#'
#' \item path: the full path to the new file or directory
#'
#' \item isdir: boolean; TRUE iff the path is a directory
#'
#' \item test: boolean; TRUE on the first call of the function for a
#'  given new file or folder; FALSE on the second call
#'
#' \item val: object; NULL on the first call; the return value
#' of the first call on the second call.  This permits passing
#' information between the first and second call of the handler.
#'
#' }
#'
#' The handler function is called first with \code{test=TRUE}.  Further
#' action depends on whether the return value \code{V} is NULL:
#' \itemize{
#' \item \code{V: NULL}: do not call the handler again for this file/dir.
#' \item \code{V: not NULL}: call the handler again with \code{test=FALSE, val=V}
#' }
#'
#' If the second call to a handler returns NULL, no further handlers
#' are run for that object.
#'
#' Between the first and second call to a handler (for a given file or
#' folder), a recursive hardlink shadow copy of the incoming file or
#' folder is created, so that the second call can dispose of the files
#' as needed without preventing subsequent handlers from using them
#' too.
#'
#' Handlers are called for each file or folder already in the watch
#' directory, and then for each file or folder created in, moved
#' into, or linked to from that directory.  Handlers are permitted to
#' copy, move, or delete files, but must not modify them in-place.
#'
#' @param logFun a function to which log messages are
#'     passed.  Defaults to a function which cat()s its arguments to
#'     stderr.  \code{logFun} should have the parameter list "..."
#'
#' @return This function does not return.
#'
#' @note If a directory is added by creating a symlink to it in
#'     \code{/sgm/incoming}, ownership of files in the directory
#'     remains with the files' creator, and this function will not
#'     delete them.  Otherwise, ownership is assumed by this function,
#'     and after all handlers have been called, files are deleted.
#'     Each handler is passed a directory populated with hardlinks to
#'     the original files.  That way, the handler can move or delete
#'     the files without consequence to either other handlers or the
#'     caller.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

server = function(handlers, logFun) {
    ensureServerDirs()
    watchDir = "/sgm/incoming"

    if (missing(logFun)) {
        logFun = function(...) cat(..., "\n", file=stderr())
    } else if (! is.function(logFun) || ! isTRUE(names(formals(logFun)) == "...")) {
        stop("logFun must be a function accepting a single '...' argument")
    }

    ## launch inotifywait to report copying into, moving into, and
    ## link creation in the spool directory; report events and
    ## filenames.  Everything after the first colon is part of the
    ## path to the file

    evtCon = pipe(
        paste("inotifywait -q -m -e close_write -e moved_to -e create --format %e:%f", watchDir),
        "r")

    ## initialize file queue with list of files in watch directory.
    ## Some of these might be created after starting evtCon but
    ## before calling dir(), so we consume any events for these files
    ## without adding them to the queue.

    queue = dir(watchDir)

    repeat {
        f = readLines(evtCon, n=1)
        logFun("Got event ", f)
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
            logFun("Handling ", queue[1])
            p = file.path(watchDir, queue[1])
            info = file.info(p)

            for (h in handlers) {
                if (! is.function(h) || ! sort(names(formals(h))) == c("isdir", "path", "test", "val"))
                    stop("Handler must be a function with formals 'path', 'isdir', 'test', and 'val'")
                val = h(path=p, isdir=info$isdir, test=TRUE, val=NULL)
                if (! is.null(val)) {
                    ## create a temporary directory or file for each handler
                    tmpd = tempfile(tmpdir="/sgm/tmp")
                    if (info$isdir)
                        dir.create(tmpd, mode="0750")

                    ## copy the file or dir via hardlinks
                    safeSys("/bin/cp", "-l", "-r", p, tmpd)
                    logFun("Using copy ", tmpd)

                    ## do stuff
                    tryCatch(
                    {
                        h(path=p, isdir=info$isdir, test=FALSE, val=val)
                        unlink(tmpd, recursive=TRUE)
                        logFun("Deleting copy ", tmpd)
                    }, error = function(e) {
                        logFun("Exception while running handler", e)
                    })
                }
            }

            ## drop file/dir from queue
            queue = queue[-1]

            ## delete the original item; if it was a symlink, the target
            ## is not deleted
            unlink(p, recursive=TRUE)
            logFun("Deleted original ", p)
        }
        ## wait for a new file/dir
        logFun("Reading from queue")
        f = readLines(evtCon, n=1)
        logFun("Got event ", f)
        f = sub("^[^:]*:", "", f)
        queue = f
    }
}
