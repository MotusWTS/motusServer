#' Unpack an email message, returning the text portion.
#'
#' Unpacks a raw RFC-822 style email message, possibly with attachments,
#' into a temporary directory, and return the first text part, possibly
#' preceded by some headers.
#'
#' @param path path to the raw email message
#'
#' @param tmp directory in which the new temporary directory is created
#'
#' @param headers character vector of message header lines to include at the
#' start of the returned message.  Defaults to "Subject".
#'
#' @param maxHeaderLines maximum number of lines assumed to be headers in
#' the message.
#'
#' @return a character scalar consisting of any selecte headers
#'     followed by the first text part of the message.  This has a
#'     single attribute named "tmpdir", which is the full path to the
#'     temporary directory where the message parts have been unpacked.
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

unpackEmail = function(path, tmp, headers=c("Subject", "Reply-To:"), maxHeaderLines=500) {

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

    tmpdir = tempfile(tmpdir="tmp")
    dir.create(tmpdir)

    ## because the incoming email might (incorrectly) use \r\n end of lines,
    ## convert these to \n
    system(sprintf("cat %s | sed -e 's/\\r$//' | munpack -C %s -q -t", path, tmpdir))

    parts = dir(tmpdir, full.names=TRUE)
    textpart = match("part1", basename(parts))

    if (is.na(textpart)) {
        ## nothing unpacked, so just use original message
        msg = paste0(paste0(readLines(path), collapse="\n"), "\n")
    } else {
        ## paste the subject line and first text part of the message (if any)
        msg = paste0(paste0(c(h, readLines(parts[textpart])), collapse="\n"), "\n")
    }

    return(structure(msg, tmpdir=tmpdir))
}
