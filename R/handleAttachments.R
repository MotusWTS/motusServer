#' Handle attachments to an incoming data email.
#'
#' The email must already have been unpacked into the specified
#' directory.
#'
#' Attachments can be of type:
#' \itemize{
#' \item .DTA files from a lotek receiver
#' \item .txt.gz  compressed files from an SG
#' \item .txt  uncompressed files from an SG
#' \item .zip compressed archive holding any of the above types
#' \item .7z ...
#' \item .rar ...
#' }
#'
#' Any attachment whose filename suffix matches one of the above will
#' be enqueued.  Note:  in the odd case where a user attaches individual
#' SG .txt and .txt.gz files to a message, these will be processed in
#' alphabetical order, which should assure the corresponding site
#' is processed incrementally for each file.
#'
#' @param dir directory in which the email has been unpacked into parts.
#'
#' @return an integer vector with two elements: the number of
#'     attachments handled and the total number of message parts.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleAttachments = function(dir) {
    if (! isTRUE(file.info(dir)$isdir))
        stop("need a directory")

    ## look for files recursively, because they might be parts of messages
    ## which were themselves message attachments.

    parts = dir(dir, full.names=TRUE, recursive=TRUE)

    goodParts = grep(MOTUS_FILE_ATTACHMENT_REGEX, parts, perl=TRUE, value=TRUE)

    for (p in goodParts) {
        motusLog("Queueing %s", p)
        enqueue(p)
    }
    return(c(length(goodParts), length(parts)))
}
