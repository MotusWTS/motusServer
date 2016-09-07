#' Create a temporary filename or folder for the motus server.
#'
#' @param isdir boolean scalar: if TRUE, a temporary folder is created; otherwise,
#' a file is created
#'
#' @return invisible(NULL)
#'
#' @seealso \link{\code{server}}
#' 
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusTempPath = function(isdir) {
    
    tmpd = tempfile(tmpdir=MOTUS_PATH$TMP)
    if (isdir) {
        dir.create(tmpd, mode=MOTUS_DEFAULT_FILEMODE)
    } else {
        close(file(tmpd, "wb"))
        Sys.chmod(tmpd, mode=MOTUS_DEFAULT_FILEMODE)
    }
    invisible(NULL)
}
