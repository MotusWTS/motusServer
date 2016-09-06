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
#' @param msg character scalar message content.  This is treated as a
#'     \code{sprintf}-style formatting string, with fields filled in
#'     from \code{...}.
#'
#' @param ... paramters for replacing \code{sprintf} formatting codes
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
    msg = sprintf(msg, ...)
    sendmail(MOTUS_OUTGOING_EMAIL_ADDRESS, to, subj, msg)
    saveMsg = file.path(MOTUS_PATH$OUTBOX, format(Sys.time(), MOTUS_OUTGOING_MSG_FILENAME_FMT))
    writeLines(msg, saveMsg)
    motusLog("Emailed %s subj: \"%s\" body: %s", to, subj, saveMsg)
    invisible(NULL)
}
