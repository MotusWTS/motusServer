#' handler for new incoming email
#'
#' called by \code{\link{emailServer}} for new messages
#'
#' @param j the job; it has this field:
#' \itemize{
#' \item msgFile: full path to message file
#' }
#'
#' @return TRUE if the email message was successfully handled
#'
#' @seealso \code{\link{emailServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleEmail = function(j) {
    msg = j$msgFile
    txt = textFileContents(msg)

    auth = j$auth = validateEmail(txt)

    ## for now, be strict about token expiry
    valid = j$valid = ! (is.null(auth) || auth$expired)

    if (! valid) {
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

    ## get address(es) of people to reply to; we only send replies for valid emails

    replyTo = unique(regexPieces("(?m)(?:^From: )(?<from>.*$)|(?:^Reply-To: )(?<reply_to>.*$)", txt) [[1]])
    replyTo = grep("@dropbox.com|@wetransfer.com|@google.com", replyTo, invert=TRUE, value=TRUE, perl=TRUE)
    j$replyTo = replyTo

    path = j$path
    newmsg = file.path(path, basename(msg))
    file.rename(msg, newmsg)

    ## unpack the email
    msg = unpackEmail(newmsg, path)

    ## compress the original
    safeSys("bzip2", newmsg)

    ## remove "quoted block" formatting (e.g. "> > > ") which might
    ## result in word-wrapped original text and broken up URLs in
    ## forwarded messages (looking at you, fastmail.fm!)

    msg = gsub("\n(> )+", "", msg, perl=TRUE)

    ## parse out and enqueue links to remote data storage
    queueDownloads(j, msg)

    ## drop text parts with names like "partN"
    file.remove (
        dir(path,
            pattern    = "^part[0-9]+$",
            recursive  = TRUE,
            full.names = TRUE
            )
    )
    return (TRUE)
}
