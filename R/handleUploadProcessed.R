#' handler for completion of processing of an uploaded file
#'
#' Sends a message to the uploader giving the status of processing.
#' If \code{topJob(j)} has an item named \code{emailAttachment},
#' then that is a list of named file attachments which will be
#' included in the summary message.
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
### FIXME: decide on a method for notifying users.  Email might still make sense,
### but user should be able to select other options.  E.g. punt this to motus via
### an API call?

     tj = topJob(j)

     replyTo = tj$replyTo[1]
     if (length(replyTo) > 0) {
         email(replyTo, paste0("motus job ", tj, ": processing complete"),
           paste0("Thank-you for the upload - it has been processed.  Any product(s) are listed here:\n\n   ",
                  paste(sapply(jobProduced(tj), URLencode), collapse="\n   "),
                  "\n\nProcessing Summary:\n\n", tj$summary_, "\n\nYou can see the detailed log here:

    https://sgdata.motus.org/status

 if you log in with your motus.org credentials.

 Regards,

 The people at motus.org / sensorgnome.org
 "
 ), attachment = tj$emailAttachment)
     }
    return(TRUE)
}
