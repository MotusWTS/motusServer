#' Create a filename or folder for the motus processing queue.
#'
#' @param isdir boolean scalar: if TRUE, the default, a temporary
#'     folder is created; otherwise, a file is created
#'
#' @param ... additional components for the file or folder name
#'
#' @param dir path to folder in which to create new folder or file;
#'     default: \code{MOTUS_PATH$TMP}
#'
#' @param create if TRUE (the default), create the folder or (empty)
#'     file before returning.
#' 
#' @details  The name for the new path is a timestamp with any additional
#' components specified in \code{...} pasted afterward, separated by MOTUS_QUEUE_SEP
#' which defaults to ',' (comma); e.g. 2016-09-14T00-43-29.586886,dta
#'
#' @return the path to the new file or folder
#'
#' @seealso \link{\code{server}}
#' 
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

makeQueuePath = function( ..., isdir=TRUE, dir=MOTUS_PATH$TMP, create=TRUE) {
    
    path = file.path(dir, paste(c(format(Sys.time(), MOTUS_TIMESTAMP_FORMAT),...), collapse=MOTUS_QUEUE_SEP))
    if (create) {
        if (isdir) {
            dir.create(path, mode=MOTUS_DEFAULT_FILEMODE)
        } else {
            close(file(path, "wb"))
            Sys.chmod(path, mode=MOTUS_DEFAULT_FILEMODE)
        }
    }
    return(path)
}
