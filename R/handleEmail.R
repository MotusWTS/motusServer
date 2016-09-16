#' handler for incoming email
#'
#' called by \code{\link{server}} for emails.
#'
#' @param path the full path to the new file or directory
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @param params not used
#'
#' @return TRUE if the file is an email; FALSE otherwise
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleEmail = function(path, isdir, params) {
    ## an email must be a single file, not a dir, and match the
    ## pattern for email message files

    if (isdir)
        return (FALSE)

    ## validate
    ue = validateEmail(paste(readLines(path), collapse="\n"))

    ## unpack the email
    msg = unpackEmail(path)

    ## for now, be strict about token expiry
    valid = ! (is.null(ue) || ue$expired)

    ## archive message
    archiveMessage(path, valid)

    if (valid) {
        ## parse out and enqueue links to remote data storage
        queueDownloadableLinks(msg)

        ## drop text parts with names like "partN"
        tmpdir = attr(msg, "tmpdir")
        file.remove (
            dir(tmpdir,
                pattern    = "^part[0-9]+$",
                recursive  = TRUE,
                full.names = TRUE
                )
        )
        
        ## deal with any remaining attached files of known type
        queueKnownFiles(tmpdir)
    }
    return (TRUE)
}
