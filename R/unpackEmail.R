#' Unpack an email message, returning the text portion.
#'
#' Unpacks a raw RFC-822 style email message, possibly with
#' attachments, into the "attachments" subdirectory, and return the
#' concatenation of all text parts, possibly preceded by some headers.
#'
#' @param msg path to the raw email message
#'
#' @param dir path to folder where message parts should be unpacked
#'
#' @param headers character vector of message header lines to include at the
#' start of the returned message.  Defaults to \code{"Subject"}.
#'
#' @param maxHeaderLines maximum number of lines assumed to be headers in
#' the message.
#'
#' @return a character scalar consisting of any selected headers
#'     followed by the texts part of the message.  All text parts are
#'     returned so that messages forwarded as attachments can be
#'     blessed with a token. e.g. if I receive an email without a
#'     token, but trust the sender and content, I can forward the
#'     message as an attachment to data@sensorgnome.org with my own
#'     token in the subject or body of a new email.
#'
#' If the message is not a multi-part mime message, the full text of
#' the message is returned instead.
#'
#' @note  Trailing DOS-style newlines are translated into unix-style newlines
#' before unpacking the message, since \code{munpack} can't handle this.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

unpackEmail = function(msg, dir, headers=c("Subject"), maxHeaderLines=500) {

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

    ## because the incoming email might (incorrectly) use \r\n end of lines,
    ## convert these to \n
    res = safeSys(sprintf("cat %s | sed -e 's/\\r$//' | munpack -C %s -q -t", msg, dir), quote=FALSE)
    res = read.csv(textConnection(res), sep=" ", header=FALSE, as.is=TRUE)
    names(res) = c("name", "mime")
    textParts = file.path(dir, subset(res, mime=="(text/plain)")$name)

    if (length(textParts) == 0){
        ## nothing unpacked, so just use original message
        msg = paste0(paste0(readLines(path), collapse="\n"), "\n")
    } else {
        ## paste the subject line and text parts of the message (if any)
        msg = paste0(paste0(c(h, unlist(lapply(textParts, readLines))), collapse="\n"), "\n")
    }
    return(msg)
}
