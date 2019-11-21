#' handle a folder of Lotek .DTA files
#'
#' Called by \code{\link{processServer}} for a file or folder added
#' to the queue.  Merges files into receiver DBs, then queues
#' a job to run the tag finder on each of these.
#'
#' @param j the job with these item(s):
#' \itemize{
#'    \item filePath; path to files to be merged; if NULL, defaults to \code{jobPath(j)}
#' }
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

handleLtFiles = function(j) {
    path = j$filePath
    if (is.null(path))
        path = jobPath(j)

    ## merge files into receiver database(s)

    info = ltMergeFiles(path, topJob(j))

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
        newSubJob(j, "LtFindtags", serno=f$serno[1], tsStart=min(f$ts[f$dataNew], na.rm=TRUE))
        newSubJob(topJob(j), "exportData", serno=f$serno[1])
        newSubJob(topJob(j), "plotData", serno=f$serno[1], ts=c(min(f$ts, na.rm=TRUE), max(f$tsLast, na.rm=TRUE)))
    }

    info %>% group_by(serno) %>% do (ignore = runReceiver(.))

    if (any(info$dataNew)) {
        jobLog(j, "\nThere may be a delay between the time this job finishes and the time when new information appears on the website and is available through the R package, which varies depending on how much data has been submitted recently. Typical delays are ~20 minutes, and only rarely more than an hour. Also, please note that detections on the website are filtered, so you may not be able to see every detection there. Unfiltered data is available through the Motus R package. (See https://motus.org/MotusRBook/)", summary=TRUE)
    }

    return(TRUE)
}
