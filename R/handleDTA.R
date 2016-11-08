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
#' @seealso \link{\code{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDTA = function(j) {

    ## merge files into receiver database(s)

    info = ltMergeFiles(j$dir) %>% arrange(serno) %>% group_by(serno)

    ## queue findtags subjobs for each receiver having data files with
    ## new content

    runReceiver = function(f) {
        ## nothing to do if no new files to use

        if (! any(f$dataNew)) {
            jobLog(paste0("Receiver ", f$serno[1], ":  the .DTA files have no new data, so the tagfinder will not be run"))
            return(0)
        }
        newSubJob(j, "findtagsLt", serno=f$serno[1], tsStart=min(f$ts[f$dataNew]))
    }

    info %>% do (ignore = runReceiver(.))

    return(TRUE)
}
