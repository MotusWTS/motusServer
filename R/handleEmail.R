#' handler for incoming email
#'
#' called by \link{\code{server}} for emails.
#'
#' @param path: the full path to the new file or directory
#'
#' @param isdir: boolean; TRUE iff the path is a directory
#'
#' @param test: boolean; TRUE on the first call to this function
#'
#' @param val: object; on first call, NULL; on second call, path to
#'     temporary directory where email was unpacked into multiple text
#'     and attachment parts.
#'
#' @return
#' When \code{test} is TRUE,
#' \enumerate{
#'
#'    \item if the email includes a valid token, saves a compresseded
#'      copy in \code{/sgm/emails} and returns a list with username,
#'      email, and path to unpacked file components.  See
#'      \link{\code{getUploadToken}} for details on tokens.
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
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleEmail = function(path, isdir, test, val) {
    if (test) {
        ## grab the (first) Subject: and From: line, which we assume is in the
        ## first 500 lines of the message.

        hdrs = readLines(path, n=500)
        subj = hdrs %>% grep("^Subject:", ., perl=TRUE) %>% head(1)

        ## unpack the email

        tmpdir = tempfile(tempdir="/sgm/tmp")
        dir.create(tmpdir)
        safeSys("/usr/bin/munpack", "-C", tmpdir, "-q", "-t", path)
        parts = dir(tmpdir, full.names=TRUE)
        textpart = match("part1", basename(parts))

        ## paste the subject line and first text part of the message (if any)

        msg = paste0(subj, "\n", readChar(parts[textpart], n = file.info(parts[textpart])$size))

        ## validate
        ok = TRUE
        valid = validateEmail(msg)

        ## for now, be strict about token expiry

        if (is.null(valid) || valid$expired) {
            valid = NULL
        } else {
            ## figure out what kind of email this is
            kind = splitToDF(dataTransferRegex, msg, guess = FALSE)

            ## TODO: complete this; return value is a dataframe with one or more rows
            ## and columns for each of the possible link types.

        }

        ## archive compressed message in either emails or spam directory
        system(sprintf("cat %s \ /usr/bin/lzip -o %s", path, file.path("/sgm", if (is.null(valid)) "spam" else "emails", paste0(basename(path), ".lz"))))

        return (valid)
}
