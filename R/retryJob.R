#' Retry a job, after some external error condition has been fixed
#'
#' Jobs often end in an error that requires external intervention.
#' After such intervention has taken place, this function can be
#' called to re-run those subjobs which either had an error, or
#' which were run after a subjob with an error.
#'
#' @param j the job, as an integer scalar job number. This can be a
#'     top-level job, or one of its sub-jobs; in the latter case, the
#'     top-level job is used anyway.
#'
#' @param msg a message explaining how the error condition was fixed.
#'
#' @details All subjobs of \code{j} with errors will be re-run.
#' In addition, any subjob of \code{j} which ran after a subjob
#' with errors will also be re-run.
#'
#' To do this, the function:
#' \itemize{
#' \item sets \code{sj$done} to 0 for any subjob \code{sj} where
#' \code{sj$done < 0} or for any subjob last run after such a subjob
#' \item sets \code{j$path} to \code{MOTUS_PATH$QUEUEx} where x is the value of the job's
#' queue.
#' \item moves the job folder from its current location to \code{MOTUS_PATH$QUEUEx}
#' }
#'
#' One of the process servers watching queue 0 will then claim the job
#' and re-run those subjobs touched above, as well as any which had not
#' been run.
#'
#' @return  TRUE if the job was found and resubmitted to queue 0.
#' FALSE otherwise.
#'
#' @seealso \code{\link{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

retryJob = function(j, msg="external error corrected") {
    if (is.numeric(j))
        j = Jobs[[j]]
    j = topJob(j)
    if (is.null(j)) {
        warning("invalid job number")
        return(FALSE)
    }
    ## figure out which subjobs need rerunning

    jid = as.integer(j)
    ## subjobs with errors
    badKids = Jobs[stump == R(jid) & done < 0]
    if (length(badKids) == 0) {
        warning("job did not end in error")
        return (FALSE)
    }

    ## subjobs that run after any with errors
    bktime = min(mtime(badKids))
    cronies = Jobs[stump == R(jid)]
    cronies = cronies[mtime(cronies) >= bktime & cronies != jid]

    ## re-bless with the correct class (arrrg - poor design in Copse.R)
    cronies = Jobs[[cronies]]

    ## mark cronies as needing re-run
    cronies$done = 0

    ## move top level job to queue 0 so it can be reclaimed by one of the processes
    j$queue = 0
    moveJob(j, MOTUS_PATH$QUEUE0)
    jobLog(j, sprintf("===============================================================================\nRestarted job after error(s) found.\nReason: %s\n===============================================================================\n", msg))
    jobLog(j, "=== Restarted ===", summary=TRUE)
    return(TRUE)
}
