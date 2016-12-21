#' Load unfinished jobs from server database and enqueue them.
#'
#' @param topJob integer; the topjob for which unfinished subjobs will be queued
#'
#' @return the number of subjobs enqueued in the global \code{MOTUS_QUEUE}.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

queueUnfinishedSubjobs = function(topJob) {
    topJob = as.integer(topJob)[1]
    if (is.na(topJob))
        return(0)

    ## get unfinished jobs by id of topJob
    jj = query(Jobs, paste0("select t1.id from jobs as t1 where t1.done = 0 and t1.stump=",  topJob))[[1]]
    for (j in jj) {
        job = Jobs[[j]]
        queueJob(job)
    }
    return(length(jj))
}
