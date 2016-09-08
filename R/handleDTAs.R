#' handle a folder of .DTA files
#'
#' Called by \code{\link{server}} for a file or folder added
#' to the queue.
#'
#' @param path the full path to the file or directory.  It is only
#'     treated as a file of DTA files if it is a directory whose name
#'     begins with "dta_"
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @return TRUE iff the .DTA files were successfully handled.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDTAs = function(path, isdir) {
    if (! isdir || ! grepl("^dta_", path, perl=TRUE))
        return (FALSE)

    handled = TRUE
    
    ## first try running the new way
    rv = ltMergeFiles(MOTUS_PATH$RECV, path)

    ## log any errors
    if (any(is.na(rv$err))) {
        motusLog("HandleDTA errors: %s", paste0("   ", rv$err[!is.na(rv$err)], collapse="\n"))
        handled = FALSE
    }

    ## try running the old way
    
}
