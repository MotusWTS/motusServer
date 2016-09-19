#' handle a folder of files from one or more sensorgnomes
#'
#' Called by \code{\link{server}} for a file or folder added
#' to the queue.
#'
#' @details For each unique SG serial number found among the names of
#'     the incoming files, a temporary folder is created, and
#'     corresponding files are moved there.  That folder is then enqueued
#'     with a name beggining with "sgsingle_" (see \link{\code{server}})
#'
#' @param path the full path to the file or directory.  It is only
#'     treated as a file of sensorgnome files if it is a directory
#'     whose name ends with "_sg_PATH".
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @param params not used
#'
#' @return TRUE iff the sensornome files were successfully handled.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleSG = function(path, isdir, params) {
    if (! isdir)
        return (FALSE)

    handled = TRUE

    ## run files the new way
    rv = sgRunNewFiles(path)

    rv = cbind(rv, getYearProjSite(paste0("SG-", rv$serno), rv$ts))

    ## deal with any files where we were unable to get the project or site
    unknown = with(rv, is.na(proj) | is.na(site))
    embroilHuman(rv$name[unknown], "Unable to determine the project and/or site for these files")

    rv = subset(rv, ! unknown)
    ## queue a reprocessing of each old site with the new files

    ## function to handle files from one old site
    queueOldSite = function(files) {
        ## move files for this receiver to a new temp folder
        tmpdir = makeQueuePath("sgold", gsub('/', '%', fixed=TRUE, oldSitePath(files$year[1], files$proj[1], files$site[1])))
        file.rename(files$name, file.path(tmpdir, basename(files$name)))
        enqueue(tmpdir)
    }

    rv %>% group_by(year, proj, site) %>% do(ignore = queueOldSite(.))

    return(handled)
}
