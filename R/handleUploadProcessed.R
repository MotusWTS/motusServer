#' handler for completion of processing of an uploaded file
#'
#' Sends a message to the uploader giving the status of processing.
#'
#' @param j the job
#'
#' @return TRUE always.
#'
#' @seealso \code{\link{emailServer}}, \code{\link{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleUploadProcessed = function(j) {
    tj = topJob(j)

    email(tj$replyTo[1], paste0("motus job ", tj, ": processing complete"),
              paste0("Thank-you for the data upload.\nWe have processed your file
and the summary of results is:\n\n", tj$summary, "\n\nYou can see the detailed log here:

   https://sensorgnome.org/My_Job_Status

if you are logged-in with your sensorgnome.org credentials.

Regards,

The people at motus.org / sensorgnome.org
"
))

    return(TRUE)
}
