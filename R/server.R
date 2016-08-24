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
#' @param handlers list of function to be called when a new file or
#'     folder is added to \code{/sgm/incoming}.  Each function must
#'     accept a single chararacter parameter, which will be a path to
#'     a temporary directory containing the new file(s).  Each
#'     function must return TRUE if all files were processed
#'     successfully, or FALSE otherwise.  Returning FALSE will prevent
#'     the temporary directory and its files from being deleted.
#'     Handlers are called once for each file or folder already in the
#'     watch directory, and then once for each file or folder created
#'     in, moved into, or linked to from that directory.  Handlers are
#'     permitted to copy, move, or delete files, but must not modify
#'     them in-place.
#'
#' @param logFun a function to which log messages are
#'     passed.  Defaults to a function which uses cat()s its arguments to
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
        logFun = function(..) cat(..., "\n", file=stderr())
    } else if (! is.function(logFun) || length(formals(logFun)) != 1) {
        stop("logFun must be a function accepting a single argument")
    }

    ## launch inotifywait to report copying into, moving into, and
    ## link creation in the spool directory; report events and
    ## filenames.  Everything after the first colon is part of the
    ## path to the file

    evtCon = pipe(
        paste("inotifywait -q -m -e close_write -e moved_to -e create --format %f", watchDir),
        "r")

    ## initialize file queue with list of files in watch directory.
    ## Some of these might be created after starting evtCon but
    ## before calling dir(), so we consume any events for these files
    ## without adding them to the queue

    queue = dir(watchDir)

    repeat {
        f = readLines(evtCon, n=1)
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
                ## create a temporary directory for each handler
                tmpd = tempfile()
                dir.create(tmpd, mode="0750")

                ## copy the file or dir via hardlinks
                system(paste("cp -l -r", p, tmpd))
                logFun("Using tempdir ", tmpd)

                ## do stuff
                tryCatch( {
                    if (isTRUE(h(tmpd))) {
                        ## remove the temporary directory
                        unlink(tmpd, recursive=TRUE)
                        logFun("Deleting tempdir ", tmpd)
                    }
                }, error = function(e) {
                    logFun("Exception while running handler")
                })
            }

            ## drop file/dir from queue
            queue = queue[-1]

            ## delete the original item; if it was a symlink, the target
            ## is not deleted
            unlink(p, recursive=TRUE)
            logFun("Deleted original ", p)
        }
        ## wait for a new file/dir
        queue = readLines(evtCon, n=1)
    }
}
