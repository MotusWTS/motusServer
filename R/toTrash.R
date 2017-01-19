#' send files to the trash folder for eventual deletion
#'
#' We keep all "dispoable" files in one folder.  They are retained there
#' until we can verify they are no longer needed.  Perhaps we'll reap
#' them periodically after X weeks.  The trash file is \code{MOTUS_PATH$TRASH}.
#'
#' @param f character vector of full paths to files
#'
#' @return  TRUE
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

toTrash = function(f) {
    moveFilesUniquely(f, MOTUS_PATH$TRASH)
}
