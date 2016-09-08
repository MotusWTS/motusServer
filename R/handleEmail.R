#' handler for incoming email
#'
#' called by \code{\link{server}} for emails.
#'
#' @param path the full path to the new file or directory
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @return TRUE if the file is an email; FALSE otherwise
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleEmail = function(path, isdir) {
    ## an email must be a single file, not a dir, and match the
    ## pattern for email message files

    if (isdir || ! grepl(MOTUS_EMAIL_FILE_REGEX, basename(path), perl=TRUE))
        return (FALSE)

    ## unpack the email
    msg = unpackEmail(path)

    ## validate
    ue = validateEmail(msg)

    ## for now, be strict about token expiry
    valid = ! (is.null(ue) || ue$expired)

    ## archive message
    archiveMessage(path, valid)

    if (valid) {
        ## parse out and enqueue links to remote data storage
        queueDownloadableLinks(msg)

        ## deal with any attached files of known type
        queueKnownFiles(attr(msg, "tmpdir"))
    }
    return (TRUE)
}
