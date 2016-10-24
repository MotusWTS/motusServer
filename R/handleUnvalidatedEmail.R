#' handler for email with missing or expired validation token
#'
#' Sends a copy of the unvalidated email to MOTUS_ADMIN_EMAIL, which
#' allows that person to paste in a token and resubmit the email if
#' it is valid.
#'
#' Called by \code{\link{emailServer}}
#'
#' @param j the job
#'
#' @return TRUE if the unvalidated email message was successfully handled
#'
#' @seealso \code{\link{emailServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleUnvalidatedEmail = function(j) {
    tj = topJob(j)
    txt = paste0(paste0(readLines(bzfile(tj$msgFile, "rb")), collapse="\n"), "\n")

email(MOTUS_ADMIN_EMAIL, "Missing or expired token in email",
              paste0("The message below was received by data@sensorgnome.org,
but lacks a valid authorization token.

If this is a valid data email, you can paste your own authorization token
into the subject or body, then forward it to data@sensorgnome.org

You can also forward it to the original sender with the above instructions.

Whoever sends the new copy (with token) to data@sensorgnome.org will receive
the status messages.

----------------------------------------------------------------------------
", txt))
    jobFail(j, "Missing or expired token in email")

    return(TRUE)
}
