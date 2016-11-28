#' process batches of files from the queue
#'
#' The queue consists of items in the \code{MOTUS_PATH$QUEUE<N>}
#' folder.  When the queue is empty, it is fed an item from the
#' \code{MOTUS_PATH$QUEUE0} folder, which receives processed email messages
#' and directly moved folders.
#'
#' Processing an item in the queue usually leads to more items being
#' added to the queue, and these are processed in depth-first order;
#' i.e. if X1 is a subjob of X and Y1 is a subjob of Y, and X was
#' created before Y, and X1 and Y1 are both in the queue, then X1 will
#' be processed before Y1, regardless of which was enqueued first.
#'
#' @param N integer queue number in the range 1..8, this process
#' will perform its operations in the folder \code{MOTUS_PATH$QUEUE\emph{N}}
#'
#' @param tracing boolean scalar; if TRUE, enter the debugger before
#' each handler is called
#'
#' @return This function does not return; it is meant for use in an R
#'     script run in the background.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

processServer = function(N, tracing=FALSE) {
    if(tracing)
        options(error=recover)

    MOTUS_PROCESS_NUM <<- N

    ensureServerDirs()

    MOTUS_SERVER_DB_SQL <<- ensureServerDB()

    motusLog("ProcessServer started for queue %d", N)

    loadJobs(N)

    ## get a feed of email messages

    feed = getFeeder(MOTUS_PATH$QUEUE0, tracing=tracing)

    ## kill off the inotifywait process when we exit this function
    on.exit(feed(TRUE), add=TRUE)

    pkgEnv = as.environment("package:motusServer")

    repeat {

        if (length(MOTUS_QUEUE) == 0) {
            jobPath = feed()    ## this might might wait a long time

            ## try to claim the given job; the jobPath looks like /sgm/queue/0/00000123
            j = Jobs[[as.integer(basename(jobPath))]]

            if (is.null(j) || ! claimJob(j, N)) {
                ## another process presumably claimed the job before us, or the job
                ## was deleted
                next
            }

            ## log this enqueuing in job and globally
            ## queue the subjobs which are not already done
            nsj = loadJobs(topJob=j)
            msg = sprintf("Job %d with %d pending subjobs entered processing queue #%d", j, nsj, N)
            motusLog(msg)
            jobLog(j, msg)
            next

        } else {

            j = Jobs[[MOTUS_QUEUE[1]]]   ## get the first job from the queue
            MOTUS_QUEUE <<- MOTUS_QUEUE[-1] ## drop the item from the queue
        }

        h = get0(paste0("handle", toupper(substring(j$type, 1, 1)), substring(j$type, 2)),
                 pkgEnv, mode="function")

        if (is.null(h)) {
            motusLog("Ignoring job %d with unknown type '%s'", j, j$type)
            ## we don't mark the job as done, in case a new version of
            ## this server, which implements a handler for this type,
            ## is run later
            next
        }

        handled = FALSE

        if (tracing) {
            browser()
            handled = h(j)
        } else {
            handled = loggingTry(j, h(j))
        }

        ## If job handler hasn't already marked a status code in the "$done"
        ## field, do so now.
        if (j$done == 0 && ! is.na(handled)) {
            if (isTRUE(handled)) {
                j$done = 1
            } else {
                j$done = -1
            }
        }
    }
}
