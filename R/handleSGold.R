#' handle a folder of files from one sensorgnome, in the old style.
#'
#' Called by \code{\link{server}} for a file or folder added
#' to the queue.
#'
#' Files are moved to the 'incoming' folder of the
#' appropriate receiver folder of the \code{/SG/} hierarchy.  The
#' old-style R script \code{update_site.R} is then run for that
#' site.  This merges files and runs the tag finder on the site's
#' entire history, against the tag database for that nominal year.
#' Results are posted to user pages on the sensorgnome.org wiki.
#' An hour-by-hour tag presence summary and plot are generated,
#' which compare old and new styles of running the data.
#'
#' @param path the full path to the directory of SG files.
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @param params character vector; first item is path to site folder in
#'     old-style hierarchy, with percent-signs representing forward slashes
#'
#' @return TRUE iff the sensornome files were successfully handled.
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleSGold = function(path, isdir, params) {
    if (! isdir) return (FALSE)

    ## rewrite '%' to '/' in site path
    sitePath = gsub('%', '/', params[1], fixed=TRUE)

    ## run the old site update script

    motusLog("Running %s old style with files here: %s", sitePath, path)

    safeSys("cd", sitePath, nq=";", "/SG/code/update_site.R", "-f", "-i", path)

    return(TRUE)
}
