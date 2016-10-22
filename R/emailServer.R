#' process incoming emails
#'
#' Watch for new messages in \code{MOTUS_PATH$INBOX}.
#'
#' When a new message is found:
#' \itemize{
#' \item create a new job folder in /sgm/email_queue
#' \item unpack its parts
#' \item validate by looking for an authorization token
#' \item save attachments
#' \item download files from any links
#' \item email the sender with an acknowledgement and pointer to a status page.
#' \item enqueue a new job with all files
#' }
#'
#' @param tracing; default FALSE.  If TRUE, enter debug browser before
#' calling each handler.
#'
#' @return This function does not return; it is meant for use in an R
#'     script run in the background.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

emailServer = function(tracing = FALSE) {
    if(tracing)
        options(error=recover)

    ensureServerDirs()
    loadJobs("email")
    motusLog("EmailServer started")

    ## get a feed of email messages

    feed = getFeeder(MOTUS_PATH$INBOX)

    ## kill off the inotifywait process when we exit this function
    on.exit(feed(TRUE), add=TRUE)

    ## the queue is a vector of job IDs, in the order they need to be completed
    MOTUS_QUEUE <<- Jobs[! done && type=="email", sort=id]

    repeat {

        if (length(MOTUS_QUEUE) == 0) {
            msg <- feed()    ## this might might wait a long time
            j <- newJob("email", path=MOTUS_PATH$MAIL_QUEUE, msgFile=msg)
            jobLog(j, paste("Received message at", basename(msg)))
            MOTUS_QUEUE <<- j
            next
        }
        j = Jobs[[MOTUS_QUEUE[1]]]   ## get the first job from the queue
        MOTUS_QUEUE <<- MOTUS_QUEUE[-1] ## drop the item from the queue

        h = get0(paste0("handle", toupper(substring(j$type, 1, 1)), substring(j$type, 2)),
                 as.environment("package:motus"), mode="function")

        if (is.null(h)) {
            motusLog("Ignoring job %d with unknown type '%s'", j, j$type)
            next
        }

        handled = FALSE

        if (tracing) {
            browser()
            handled <- h(j)
        } else {
            loggingTry(j, handled <<- h(j))
        }

        if (isTRUE(handled)) {
            j$done = 1
        } else {
            j$done = -1
        }
        ## see whether this job completes the top-level job
        if (isTopJobDone(j)) {
            tj = topJob(j)
            ## if this email had valid authorization
            if (tj$valid) {
                email(tj$replyTo[1], "motus: data transfer email received",
                      paste0("Thank-you for the data transfer.  We have tried to download your
transferred files, shared links, and/or attachments.  Results:

",
tj$log,
"
If any data were transferred, they will now enter the processing queue.
Status of the queue can be seen here:

   https://sensorgnome.org/Motus_Processing_Status

if you are logged-in with your sensorgnome.org credentials.

When your job is complete, we'll send another email to let you know where
to find the results.

Please don't reply to this email.
If you have any questions, contact mailto:",

MOTUS_ADMIN_EMAIL
))
            }
            moveJob(tj, MOTUS_PATH$QUEUE0)
        }
    }
}
