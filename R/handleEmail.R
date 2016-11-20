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
    msgFile = j$msgFile
    path = j$path
    newmsg = file.path(path, basename(msgFile))
    file.rename(msgFile, newmsg)

    ## unpack the email, and get the message text (including some headers)
    txt = unpackEmail(newmsg, path)

    ## compress the original
    safeSys("bzip2", newmsg)
    j$msgFile = paste0(newmsg, ".bz2")

    auth = validateEmail(txt)
    ## record user in own column; remainder of auth in data field
    j$user = auth$username
    j$auth = auth[- match("username", names(auth))]

    ## for now, be strict about token expiry
    valid = j$valid = ! (is.null(auth) || auth$expired)

    if (! valid) {
        newSubJob(j, "unvalidatedEmail")
        return(TRUE)
    }

    ## get address(es) of people to reply to; we only send replies for valid emails

    replyTo = unique(regexPieces("(?m)(?:^From: )(?<from>.*$)|(?:^Reply-To: )(?<reply_to>.*$)", txt) [[1]])
    replyTo = grep("@dropbox.com|@wetransfer.com|@google.com", replyTo, invert=TRUE, value=TRUE, perl=TRUE)

    ## If no useable From or Reply-To header found, use the email
    ## associated with the authorization token

    if (length(replyTo) == 0)
        replyTo = auth$email

    j$replyTo = replyTo

    ## remove "quoted block" formatting (e.g. "> > > ") which might
    ## result in word-wrapped original text and broken up URLs in
    ## forwarded messages (looking at you, fastmail.fm!)

    txt = gsub("\n(> )+", "", txt, perl=TRUE)

    ## queue a job to sanity check files; e.g. check for files that have
    ## the correct size but are all zeroes, because the user didn't wait
    ## for a sync to finish before sending the link.
    ## This lets us provide a better error message than if we just
    ## capture the error message from trying to decompress an all-zero
    ## archive, e.g.
    newSubJob(j, "sanityCheck", dir=j$path)

    ## queue a job to unpack archives
    newSubJob(j, "queueArchives", dir=j$path)

    ## parse out and links to remote data storage
    ## and enqueue jobs to download them
    queueDownloads(j, txt)

    ## queue a job that runs when all file-wrangling related to the
    ## email is complete and it's time to process the data
    newSubJob(j, "filesWrangled")

    ## queue the job for processing files
    newSubJob(j, "newFiles")

    ## drop text parts with names like "partN"
    file.remove (
        dir(path,
            pattern    = "^part[0-9]+$",
            recursive  = TRUE,
            full.names = TRUE
            )
    )

    ## top-level processing of the email is complete, although sub-jobs are not.
    return (TRUE)
}
