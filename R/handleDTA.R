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
#' @param params not used
#'
#' @return TRUE iff the .DTA files were successfully handled.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDTA = function(path, isdir, params) {
    if (! isdir)
        return (FALSE)

    handled = TRUE

    ## run files the new way
    rv = ltRunNewFiles(path)

    ## log any errors
    if (any(! is.na(rv$err))) {
        motusLog("HandleDTA errors: %s", paste0("   ", rv$err[!is.na(rv$err)], collapse="\n"))
        handled = FALSE
    }

    ## try running the old way;
    rv = cbind(rv, getYearProjSite(rv$serno, rv$ts))

    ## fix bad years; Lotek receivers don't always have correct dates

    rv$year[rv$year < 2010] = year(Sys.time())

    ## queue a reprocessing of each old site with the new files

    ## function to handle files from one old site
    queueOldSite = function(files) {
        ## move files for this receiver to a new temp folder
        tmpdir = makeQueuePath("dtaold", gsub('/', '%', fixed=TRUE, oldSitePath(files$year[1], files$proj[1], files$site[1])))
        moveFiles(files$fullname, tmpdir)

        ## name of dir in queue will be "TIMESTAMP_dtaold_%SG%YEAR%PROJ%SITE"
        enqueue(tmpdir)
    }

    rv %>% group_by(year, proj, site) %>% do(ignore = queueOldSite(.))

    return(handled)
}
