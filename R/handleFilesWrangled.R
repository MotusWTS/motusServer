#' handler for completion of email processing
#'
#' Sends reply to sender giving status of file wrangling, and moves
#' the job to the top-level motus processing queue, from which one of
#' the processServer() processes will claim it and process the files
#' transferred by the email.  Just before moving the job, a new subjob
#' of type "newFiles" is created, but not enqueued.  Whichever
#' processServer claims the job will end up enqueuing the "newFiles" subjob.
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
transferred files, shared links, and/or attachments.

If any data were transferred, they will now enter the processing queue.
You can view the status of this job
here:

   https://sensorgnome.org/My_Job_Status

and overall data processing status here:

   https://sensorgnome.org/Motus_Processing_Status

if you are logged-in with your sensorgnome.org credentials.

When your job is complete, we'll send another email to let you know where
to find the results.
-------------------------------------------------------------------------
Result of processing email:
",
tj$log, "
-------------------------------------------------------------------------
"
))
    }

    ## Create but don't enqueue the job for processing files.
    ## The job will be enqueued by the processServer that claims
    ## this from queue 0.
    newSubJob(tj, "newFiles", .enqueue=FALSE)

    ## move the topJob to the top-level processServer queue

    tj$queue = 0
    moveJob(tj, MOTUS_PATH$QUEUE0)
}
