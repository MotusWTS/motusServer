#' Queue any files of known type from a folder.
#'
#' The email must already have been unpacked into the specified
#' directory.  This function recursively deletes any files which
#' are not of usable type:
#' \itemize{
#' \item .DTA files from a lotek receiver
#' \item .txt.gz  compressed files from an SG
#' \item .txt  uncompressed files from an SG
#' \item .zip compressed archive holding any of the above types
#' \item .7z ...
#' \item .rar ...
#' }
#'
#' The folder is then enqueued.
#'
#' @param dir character vector of directories; default \code{character(0)}
#'
#' @param files character vector of full paths to files; default \code{character(0)}
#'
#' @return an integer vector with two elements: the number of
#'     attachments handled and the total number of message parts.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

queueKnownFiles = function(dir = character(0), files = character(0)) {
    ## look for files recursively in specified directories

    parts = c(files, dir(dir, full.names=TRUE, recursive=TRUE))

    goodParts = grepl(MOTUS_FILE_ATTACHMENT_REGEX, parts, perl=TRUE)

    for (p in parts[goodParts])
        enqueue(p)

    motusLog("Discarding files of unknown type: %s", paste0("   ", basename(parts[! goodParts]), collapse="\n"))

    unlink(dir, recursive=TRUE)
    return(c(sum(goodParts), length(parts)))
}
