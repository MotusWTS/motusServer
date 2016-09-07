#' Create a temporary filename or folder for the motus server.
#'
#' @param isdir boolean scalar: if TRUE, the default, a temporary
#'     folder is created; otherwise, a file is created
#'
#' @return the path to the new file or folder
#'
#' @seealso \link{\code{server}}
#' 
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusTempPath = function(isdir = TRUE) {
    
    tmpd = tempfile(tmpdir=MOTUS_PATH$TMP)
    if (isdir) {
        dir.create(tmpd, mode=MOTUS_DEFAULT_FILEMODE)
    } else {
        close(file(tmpd, "wb"))
        Sys.chmod(tmpd, mode=MOTUS_DEFAULT_FILEMODE)
    }
    return(tmpd)
}
