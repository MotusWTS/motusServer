#' handle a set of .DTA folders belonging to the same 'old-style' site
#'
#' Called by \code{\link{server}} for a file or folder added
#' to the queue.
#'
#' @param path the full path to the file or directory.  It is only
#'     treated as a file of DTA files if it is a directory whose name
#'     begins with "dtaold_"
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @param params character vector; first item is path to site folder in
#'     old-style hierarchy, with percent-signs representing forward slashes
#'
#' @return TRUE iff the .DTA files for the site were successfully handled.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDTAold = function(path, isdir, params) {
    if (! isdir)
        return (FALSE)

    ## rewrite '%' to '/' in site path
    sitePath = gsub('%', '/', params[1], fixed=TRUE)

    newFiles = dir(path)

    ## move files to site, renaming any that conflict

    moveFilesUniquely(path, sitePath)

    ## run the old site update script

    motusLog("Running %s old style with file(s): %s", sitePath, paste(newFiles, collapse="\n   "))

    safeSys("cd", sitePath, nq1=";", "/SG/code/update_lotek_site.R", "-f", shell=TRUE)

    return(TRUE)
}
