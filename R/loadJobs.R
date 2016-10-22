#' Load unfinished jobs from server database and enqueue them
#'
#' A global object \code{Jobs} is created, which manages jobs.
#' It is populated from the "jobs" table in the server database.
#'
#' It has these fixed fields:
#' \itemize{
#'
#' \item type: character; type of job
#'
#' \item done: integer; 0 if not attempted; negative for errors; +1
#' for successfully finished
#'
#' \item path: full path to folder for job
#'
#' \item oldpath: full path to previous folder for job (permits
#' recovery from server failure during job move)
#'
#' }
#'
#' Other job items are stored in a JSON-encodded text field called
#' \code{data}.
#'
#' For any jobs which are not done and whose head job is of the specified
#' type, we verify that the "path" field is correct, in case the
#' server was interrupted while moving a job.
#'
#' @param headType only examine jobs whose head job is of this type.
#'
#' @return no return value.  Jobs are enqueued in the global \code{MOTUS_QUEUE}.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

loadJobs = function(headType) {
    Jobs <<- Copse(MOTUS_SERVER_DB, "jobs", type=character(), done=integer(), path=character(), oldpath=character())

    ## get IDs of jobs with possibly incorrect paths.

    j = query(Jobs,
              paste0("select t1.id from jobs as t1 left join jobs as t2 on t1.stump=t2.id where (t1.path is not null and t1.oldpath is not null) and (t1.done == 0) and ((t2.id is NULL and t1.type=='", headType,"') or t2.type=='", headType, "') order by t1.id"))[[1]]
    for (i in j) {
        if (! file.exists(Jobs[[i]]$path) && file.exists(Jobs[[i]]$oldpath))
            Jobs[[i]]$path = Jobs[[i]]$oldpath
        queueJob(Jobs[[i]])
    }
}
