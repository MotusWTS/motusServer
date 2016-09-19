#' Send an email message.
#'
#' An email message is sent from data@sensorgnome to the specified user.
#' A log entry is made, and the outgoing message is saved in the motus
#' server outbox.
#'
#' @param to email address of recipient
#'
#' @param subj character scalar subject line
#'
#' @param msg character scalar message content. If further parameters
#'     are specified in \code{...}, this is treated as a
#'     \code{sprintf}-style formatting string, with fields filled in
#'     from \code{...}.  Otherwise, it is used as-is.
#'
#' @param ... parameters for replacing \code{sprintf} formatting codes
#'     in \code{msg}
#'
#' @return invisible(NULL)
#'
#' @seealso \link{\code{sprintf}} for formatting codes.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

email = function(to, subj, msg, ...) {
    if (length(list(...)) > 0)
        msg = sprintf(msg, ...)
    sendmail(MOTUS_OUTGOING_EMAIL_ADDRESS, to, subj, msg)
    saveMsg = makeQueuePath("out.bz2", isdir=FALSE, dir=MOTUS_PATH$OUTBOX, create=FALSE)
    f = bzfile(saveMsg, "wb")
    writeLines(
        sprintf(
            "From: %s\nTo: %s\nSubject: %s\nDate: %s",
            MOTUS_OUTGOING_EMAIL_ADDRESS,
            to,
            subj,
            format(Sys.time(), MOTUS_TIMESTAMP_FORMAT)
        ),
        f)
    writeLines(msg, f)
    close(f)
    motusLog("Emailed %s subj: \"%s\" body: %s", to, subj, saveMsg)
    invisible(NULL)
}
