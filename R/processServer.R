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
#' @param N integer queue number. If in the range 1..8, this process
#' will watch for new jobs in \code{MOTUS_PATH$QUEUE0} and will
#' store its operations in the folder \code{MOTUS_PATH$QUEUE\emph{N}}
#' If \code{N >= 101}, the process will watch for new jobs in
#' \code{MOTUS_PATH$PRIORITY}.  This is to allow high-priority jobs to run separately
#' from those handling uploaded data.  It's meant for manual runs on
#' the server, and runs for small batches of data from attached receivers.
#'
#' @param tracing boolean scalar; if TRUE, enter the debugger before
#' each handler is called
#'
#' @return This function does not return; it is meant for use in an R
#'     script run in the background.  After each subjob is handled,
#'     the function checks for the existence of a file called
#'     \code{MOTUS_PATH$QUEUE0/kill\emph{N}} or
#'     \code{MOTUS_PATH$PRIORITY/kill\emph{N}} (for N >= 101)
#'     If that file is found,
#'     the function calls quit(save="no").  The file will also
#'     be detected within the call to feed() when the queue
#'     is empty, because it is located in the watched folder.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

processServer = function(N, tracing=FALSE) {
    if(tracing)
        options(error=recover)

    MOTUS_PROCESS_NUM <<- N

    ensureServerDirs()

    serverCommon(withHTTP=FALSE)

    motusLog("Process server started for queue %d with PGID=%d", N, getPGID())

    loadJobs(N)

    INQUEUE = if (N > 100) MOTUS_PATH$PRIORITY else MOTUS_PATH$QUEUE0
    ## get a feed of email messages

    feed = getFeeder(c(INQUEUE, MOTUS_PATH[[sprintf("QUEUE%d",N)]]), tracing=tracing)

    ## kill off the inotifywait process when we exit this function
    on.exit(feed(TRUE), add=TRUE)

    pkgEnv = as.environment("package:motusServer")

    ## the kill file:
    killFile = file.path(INQUEUE, paste0("kill", N))

    if (tracing)
        browser()

    repeat {

        if (length(MOTUS_QUEUE) == 0) {
            jobPath = feed()    ## this might might wait a long time
            if (jobPath == killFile)
                break
            ## try to claim the given job; the jobPath looks like /sgm/queue/0/00000123
            j = Jobs[[as.integer(basename(jobPath))]]

            if (is.null(j) || ! claimJob(j, N)) {
                ## another process presumably claimed the job before us, or the job
                ## was deleted
                next
            }

            ## queue those subjobs which are not already done
            nsj = queueUnfinishedSubjobs(j)

            if (nsj > 0) {
                ## log this enqueuing in job and globally
                msg = sprintf("Job %d with %d pending subjobs entered processing queue #%d", j, nsj, N)
                motusLog(msg)
                jobLog(j, msg)
            } else {
                maybeRetireJob(j)
            }
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
        maybeRetireJob(j)

        ## check for a killN file
        if (file.exists(killFile))
            break
    }
    motusLog("Process server stopped for queue %d", N)
    quit(save="no")
}

#' if a job is done and none of its subjobs are left in the queue, then move
#' it to the 'done' folder
#'
#' @param j a job
#'
#' @return TRUE if the job is being retired; FALSE otherwise

maybeRetireJob = function(j) {
    if (! isTRUE(j$done == 0)) {
        tj = topJob(j)
        if (0 == length(subjobsInQueue(tj))) {
            moveJob(tj, MOTUS_PATH$DONE)
            return(TRUE)
        }
    }
    return(FALSE)
}
