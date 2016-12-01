#' process incoming emails
#'
#' Watch for new messages in \code{MOTUS_PATH$INBOX}.
#'
#' When a new message is found:
#' \itemize{
#' \item create a new job folder in /sgm/email_queue
#' \item unpack the email's parts (e.g. attachments, or enclosed forwarded messages)
#' \item validate by looking for an authorization token
#' \item save attachments
#' \item download files from any links
#' \item run basic sanity checks on files
#' \item unpack archives
#' \item email the sender with an acknowledgement and pointer to a status page.
#' \item enqueue a new job with all files
#' }
#'
#' @param tracing; default FALSE.  If TRUE, enter debug browser before
#' calling each handler.
#'
#' @return This function does not return; it is meant for use in an R
#'     script run in the background.  After each subjob is handled,
#'     the function checks for the existence of a file called
#'     \code{MOTUS_PATH$INBOX/killE}.  If that file is found,
#'     the function calls quit(save="no").  The file will also
#'     be detected within the call to feed() when the queue
#'     is empty, because it is located in the watched folder.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

emailServer = function(tracing = FALSE) {
    if(tracing)
        options(error=recover)

    ensureServerDirs()
    motusLog("Email server started")

    ## The queue is a vector of job IDs, maintained in execution order.
    ## Execution order is depth-first, sorting by job ID within a parent
    ## job.  So if a job enqueues two sub jobs X and Y, and X when run
    ## enqueues new subjobs X1, X2, and X3, then the order of execution is:

    ##    X, X1, X2, X3, Y

    ## even though Y was enqueued before X1, ..., X3.

    ## The queue is kept sorted by item names, which are the zero-padded
    ## paths in the job tree starting from the top job.
    ## This sorting occurs when new jobs are enqueued.  Removing
    ## a job preserves order and requires no additional care.

    loadJobs("email")

    ## get a feed of email messages

    feed = getFeeder(MOTUS_PATH$INBOX, messages = c("close_write", "moved_to"), tracing=tracing)

    ## kill off the inotifywait process when we exit this function
    on.exit(feed(TRUE), add=TRUE)

    pkgEnv = as.environment("package:motusServer")

    ## the kill file; must be in the same folder as passed to getFeeder,
    ## so that creating the killFile causes a return from feed() below:

    killFile = file.path(MOTUS_PATH$INBOX, "killE")

    repeat {

        if (length(MOTUS_QUEUE) == 0) {
            msg = feed()    ## this might might wait a long time
            if (msg == killFile)
                break

            ## create and enqueue a new email job
            j = newJob("email", .parentPath=MOTUS_PATH$MAIL_QUEUE, msgFile=msg)

            ## record receipt within the job's log
            jobLog(j, paste("Received message at", basename(msg)))
        }

        j = Jobs[[MOTUS_QUEUE[1]]]   ## get the first job from the queue
        MOTUS_QUEUE <<- MOTUS_QUEUE[-1] ## drop the item from the queue

        h = get0(paste0("handle", toupper(substring(j$type, 1, 1)), substring(j$type, 2)),
                 pkgEnv, mode="function")

        if (is.null(h)) {
            motusLog("Ignoring job %d with unknown type '%s'", j, j$type)
            ## we don't mark the job as done, in case a new version of
            ## this server, which implements a handler for this type,
            ## is run later
            next
        }

        ## use a global to record success in call to loggingTry() below

        motusHandled <<- FALSE

        if (tracing) {
            browser()
            motusHandled <<- h(j)
        } else {
            loggingTry(j, motusHandled <<- h(j))
        }

        ## If job handler hasn't already marked a status code in the "$done"
        ## field, do so now.
        if (j$done == 0) {
            if (isTRUE(motusHandled)) {
                j$done = 1
            } else {
                j$done = -1
            }
        }
        ## check for a killN file; we repeat the check from above, in case
        ## we're working through the pre-existing portion of the queue
        if (file.exists(killFile))
            break
    }
    motusLog("Email server stopped")
    quit(save="no")
}
