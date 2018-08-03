#' send files to the trash folder for eventual deletion
#'
#' We keep all "disposable" files in one folder, with a subfolder
#' hierarchy based on job ID.  They are retained there until we can
#' verify they are no longer needed.  A monthly cron job reaps
#' the oldest files.
#'
#' \code{MOTUS_PATH$TRASH}.
#'
#' @param f character vector of full paths to files
#'
#' @param j integer scalar jobID
#'
#' @return  TRUE
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

toTrash = function(f, j) {
    d = file.path(MOTUS_PATH$TRASH, j)
    dir.create(d)
    moveFilesUniquely(f, d)
}
