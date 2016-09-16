#' Unpack an email message, returning the text portion.
#'
#' Unpacks a raw RFC-822 style email message, possibly with
#' attachments, into a temporary directory, and return the
#' concatenation of all text parts, possibly preceded by some headers.
#'
#' @param path path to the raw email message
#'
#' @param headers character vector of message header lines to include at the
#' start of the returned message.  Defaults to \code{c("Subject", "Reply-To")}.
#'
#' @param maxHeaderLines maximum number of lines assumed to be headers in
#' the message.
#'
#' @return a character scalar consisting of any selected headers
#'     followed by the texts part of the message.  This has a
#'     single attribute named "tmpdir", which is the full path to the
#'     temporary directory where the message parts have been unpacked.
#'     All text parts are returned so that messages forwarded as attachments
#'     can be blessed with a token. e.g. if I receive an email without
#'     a token, but trust the sender and content, I can forward the message
#'     as an attachment to data@sensorgnome.org with my own token in the
#'     body of a new email.
#'
#' If the messages is not a multi-part mime message, the full text of
#' the messages is returned instead of the first text part.
#'
#' @note  Trailing DOS-style newlines are translated into unix-style newlines
#' before unpacking the message, since \code{munpack} can't handle this.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

unpackEmail = function(path, headers=c("Subject", "Reply-To:"), maxHeaderLines=500) {

    ## grab any requested header lines
    if (length(headers) > 0) {
        h = readLines(path, n=maxHeaderLines) %>%
            grep (paste0("^(", paste0(headers, collapse="|"), "):"),
                  .,
                  perl=TRUE,
                  value = TRUE)
    } else {
        h = character(0)
    }

    tmpdir = makeQueuePath("msgparts")

    ## because the incoming email might (incorrectly) use \r\n end of lines,
    ## convert these to \n
    res = system(sprintf("cat %s | sed -e 's/\\r$//' | munpack -C %s -q -t", path, tmpdir), intern=TRUE)
    res = read.csv(textConnection(res), sep=" ", header=FALSE, as.is=TRUE)
    names(res) = c("name", "mime")
    textParts = file.path(tmpdir, subset(res, mime=="(text/plain)")$name)

    if (length(textParts) == 0){
        ## nothing unpacked, so just use original message
        msg = paste0(paste0(readLines(path), collapse="\n"), "\n")
    } else {
        ## paste the subject line and text parts of the message (if any)
        msg = paste0(paste0(c(h, unlist(lapply(textParts, readLines))), collapse="\n"), "\n")
    }
    return(structure(msg, tmpdir=tmpdir))
}
