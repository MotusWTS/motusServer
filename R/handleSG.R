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

    r = sgMergeFiles(path)
    info = r$info

    ## function to queue a run of files the new way

    queueNewSession = function(f) {
        ## nothing to do if no files to use

        if (! any(f$use))
            return(0)

        bn = f$monoBN[1]
        recv = f$serno[1]

        canResume = isTRUE(r$resumable[paste(recv, bn)])

        enqueueCommand("sgnew", recv, bn, canResume)
    }

    ## queue runs of all receiver boot sessions with new data

    info %>%
        arrange(serno, monoBN) %>%
        group_by(serno, monoBN) %>%
        do (ignore=queueNewSession(.))

    info = cbind(info, getYearProjSite(paste0("SG-", info$serno), info$ts))

    ## deal with any files where we were unable to get the project or site
    unknown = with(info, is.na(proj) | is.na(site))
    embroilHuman(info$name[unknown], "Unable to determine the project and/or site for these files")

    info = subset(info, ! unknown)
    ## queue a reprocessing of each old site with the new files

    ## function to handle files from one old site
    queueOldSite = function(files) {
        ## move files for this receiver to a new temp folder
        tmpdir = makeQueuePath("sgold", gsub('/', '%', fixed=TRUE, oldSitePath(files$year[1], files$proj[1], files$site[1])))
        moveFiles(files$name, tmpdir)
        enqueue(tmpdir)
    }

    info %>% group_by(year, proj, site) %>% do(ignore = queueOldSite(.))

    return(handled)
}
