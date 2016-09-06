#' handler for incoming email
#'
#' called by \code{\link{server}} for emails.
#'
#' @param path the full path to the new file or directory
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @param test boolean; TRUE on the first call to this function
#'
#' @param val object; on first call, NULL; on second call, a list
#' with these items:
#' \itemize{
#' \item user: username
#' \item email: user email
#' \item msg: text of message
#' \item dir: temporary directory where email was unpacked into multiple text
#'     and attachment parts.
#' }
#'
#' @return
#' When \code{test} is TRUE,
#' \itemize{
#'
#'    \item if \code{isdir} is TRUE, return NULL, since the item is not
#'          an email message.
#'
#'    \item if the email includes a valid token, saves a compressed
#'      copy in \code{/sgm/emails} and returns a list with these items:
#'
#'    \itemize{
#'       \item user user name
#'       \item email user email address
#'       \item msg text portion of message, with attribute "tmpdir" giving
#'       the directory in which message components have been unpacked.
#'    }
#'    See \code{\link{getUploadToken}} for details on tokens.
#'
#'    \item otherwise, saves a compressed copy in \code{/sgm/spam} and
#'      returns NULL }
#'
#' When \code{test} is FALSE, return NULL after processing the
#' incoming message in exactly one of these ways, in the order
#' in which they are attempted:
#'
#' \itemize{
#'
#'    \item if the message has a link from wetransfer.com,
#'      e.g. \code{https://www.wetransfer.com/downloads/f242a979bd8ee4e234020014603/ff596277163052f2efae484603/b98a5c}
#'      download the file(s) into a temporary file then move it to
#'      \code{/sgm/incoming}
#'
#'    \item if the message has a shared link from google drive,
#'      e.g. \code{https://drive.google.com/folderview?id=0B-bl0wWweuhbzxvkuhspXOUU&usp=sharing}
#'      download all files from the directory (or the shared itself,
#'      if that's what it is) into a temporary folder, then move that
#'      to \code{/sgm/incoming}
#'
#'    \item if the message has a shared link from dropbox.com,
#'      e.g. \code{https://www.dropbox.com/sh/3vabcdefgrjkzin/AABRQffeddJ-2EbbfeFe-vfGa?dl=0}
#'      download all files from the directory (or the shared file
#'      itself, if that's what it is) into a temporary folder, then
#'      move it to \code{/sgm/incoming}
#'
#'    \item if the email body contains an ftp link such as
#'      \code{ftp://[user:password@]ftp://ftp.gnu.org/gnu/anubis/}
#'      then download the file or directory (recursively) pointed to
#'      by the link into a temporary directory and move that into
#'      \code{/sgm/incoming}
#'
#'    \item if the message has any attachments which are compressed
#'      archives, copy those to a temporary folder and then move the
#'      temporary folder into \code{/sgm/incoming}
#'
#' }
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleEmail = function(path, isdir, test, val) {
    if (test) {
        ## an email must be a single file, not a dir, and match the pattern
        ## for email message files
        if (isdir || ! grepl(MOTUS_EMAIL_FILE_REGEXP, basename(path), perl=TRUE))
            return (NULL)

        ## unpack the email
        msg = unpackEmail(path, "/sgm/tmp")

        ## validate
        ue = validateEmail(msg)

        ## for now, be strict about token expiry
        valid = ! (is.null(ue) || ue$expired)

        ## archive compressed message in either emails or spam directory
        ## note that .lz suffix is added automatically to "basename(path)"
        archiveMessage(path, valid)

        return (
            if (valid) {
                list(
                    user  = ue$user,
                    email = ue$email,
                    msg   = msg
                )
            } else {
                NULL
            })
    } else {
        ## parse out and handle links to remote data storage
        handleDownloadableLinks(links)

        ## deal with any attached files of known type
        handleAttachments(val)

        return (NULL)
    }
}
