#' handler for completion of email processing
#'
#' Sends reply to sender giving status of file wrangling, and moves
#' the job to the top-level motus processing queue, from which one of
#' the processServer() processes will claim it and process the files
#' transferred by the email.  The job type is changed to "newFiles".
#'
#' @param j the job
#'
#' @return TRUE if the job was successfully moved to the processing queue
#'
#' @seealso \code{\link{emailServer}}, \code{\link{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleFilesWrangled = function(j) {
    tj = topJob(j)

    ## if this email had valid authorization
    if (tj$valid) {
        email(tj$replyTo[1], paste0("motus job ", tj, ": data transfer email received"),
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

    ## change the job's type and move it to the top-level processServer queue

    tj$type = "newFiles"
    tj$queue = 0
    moveJob(tj, MOTUS_PATH$QUEUE0)
    return (TRUE)
}
