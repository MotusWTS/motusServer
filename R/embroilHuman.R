#' Save a set of files we don't know how to deal with, and request human
#' intervention.
#'
#' @details a full directory structure with any files of unknown type
#'     from an email, download, or manual folder copy is saved into a
#'     subfolder of \code{MOTUS_PATH$MANUAL}.  If all files are in the
#'     same directory, that directory is simply moved into
#'     \code{MOTUS_PATH$MANUAL}.  Otherwise, the greatest common
#'     parent path is removed from all file paths, and the files are
#'     moved to a new folder, retaining the non-shared portion of
#'     their paths.
#'
#' An email is sent to the poor chump whose job it is to deal with
#' this.
#'
#' @param files character vector of full paths to files
#'
#' @param msg additional character vector to include in the email message
#'
#' @return invisible(NULL)
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

embroilHuman = function(files, msg="") {
    if (length(files) == 0)
        return(invisible(NULL))

    dst = makeQueuePath("unknown", dir=MOTUS_PATH$MANUAL)
    dstFiles = file.path(dst, trimCommonPath(files))

    dir.create(unique(dirname(dstFiles)), recursive=TRUE, showWarnings=FALSE)
    file.rename(files, dstFiles)
    email(MOTUS_ADMIN_EMAIL, paste0("[motusServer] do something with these ", length(dstFiles), " file(s)"),
          paste0(paste(msg, collapse="\n"), "\nFiles:\n", paste("   ", dstFiles, collapse="\n")))
    invisible(NULL)
}
