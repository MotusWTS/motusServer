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
#' @param attachment named list of attachments; the list items are paths
#'     to files to attach, and the list names are the corresponding labels
#'     as they will be seen by the recipient.  Default: NULL
#'
#' @return invisible(NULL)
#'
#' @seealso \link{\code{sprintf}} for formatting codes.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

email = function(to, subj, msg, ..., attachment=NULL) {
    if (length(list(...)) > 0)
        msg = sprintf(msg, ...)
    date = format(Sys.time(), MOTUS_TIMESTAMP_FORMAT)
    embargo = file.exists("/sgm/EMBARGO_OUT")
    if (is.null(attachment)) {
        body = msg
    } else {
        body = c(list(msg), lapply(seq(along=attachment), function(i) mime_part( attachment[i], names(attachment)[i])))
    }
    if (! embargo)
        sendmail(MOTUS_OUTGOING_EMAIL_ADDRESS, to, subj, body=body)
    msgFile = file.path(if (embargo) MOTUS_PATH$OUTBOX_EMBARGOED else MOTUS_PATH$OUTBOX, paste0(date, ".txt.bz2"))
    f = bzfile(msgFile, "wb")
    writeLines(
        sprintf(
            "From: %s\nReply-To: %s\nTo: %s\nSubject: %s\nDate: %s",
            MOTUS_OUTGOING_EMAIL_ADDRESS,
            MOTUS_ADMIN_EMAIL,
            to,
            subj,
            date
        ),
        f)
    writeLines(msg, f)
    close(f)
    motusLog("Emailed %s subj: \"%s\" body: %s", to, subj, msgFile)
    invisible(NULL)
}
