#' handle a folder of .DTA files
#'
#' Called by \code{\link{processServer}} for a file or folder added
#' to the queue.  Merges files into receiver DBs, then queues
#' a job to run the tag finder on each of these.
#'
#' @param j, the job.
#'
#' @return TRUE after queueing jobs
#'
#' @note if \code{topJob(j)$mergeOnly)} is TRUE, then only merge files
#' into receiver databases; don't run the tag finder.
#'
#' @seealso \link{\code{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDTA = function(j) {

    ## merge files into receiver database(s)

    info = ltMergeFiles(jobPath(j))

    if (isTRUE(topJob(j)$mergeOnly > 0))
        return(TRUE)

    ## queue findtags subjobs for each receiver having data files with
    ## new content

    runReceiver = function(f) {
        ## nothing to do if no new files to use

        if (! any(f$dataNew)) {
            jobLog(j, paste0("Receiver ", f$serno[1], ":  the .DTA files have no new data, so the tag finder will not be run"), summary=TRUE)
            return(0)
        }
        newSubJob(j, "LtFindtags", serno=f$serno[1], tsStart=min(f$ts[f$dataNew]))
        newSubJob(topJob(j), "exportData", serno=f$serno[1])
        newSubJob(topJob(j), "plotData", serno=f$serno[1], ts=c(min(f$ts), max(f$tsLast)))
    }

    info %>% group_by(serno) %>% do (ignore = runReceiver(.))

    return(TRUE)
}
