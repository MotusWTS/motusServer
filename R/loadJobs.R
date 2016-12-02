#' Load unfinished jobs from server database and enqueue them.
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
#' \item queue: integer; the queue to which a job belongs; there is one queue
#' per running processServer().  If queue==0, the job has been enqueued
#' for processing but not yet claimed by one of the processServers().
#' If queue is null, it is being handled by emailServer() or pathServer()
#'
#' \item path: full path to folder for job
#'
#' \item oldpath: full path to previous folder for job (permits
#' recovery from server failure during job move)
#'
#' \item user: username, when job is the top job from an authenticated email
#'
#' }
#'
#' Other job items are stored in a JSON-encoded text field called
#' \code{data}.
#'
#' For any jobs to be loaded we verify that the "path" field is
#' correct, in case the server was interrupted while moving a job.
#'
#' @param which character scalar or integer scalar, which will be
#'     converted to a character scalar.  Load only jobs whose top job
#'     is in that queue.  If NULL (the default), do not actually load
#'     or queue any jobs.
#'
#' @param topJob integer; if not NULL, jobs which are not done and whose
#' topjob is this are queued.  Default: NULL.
#'
#' @return the number of jobs enqueued in the global \code{MOTUS_QUEUE}.
#' The Jobs are stored in the global \code{Jobs}.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

loadJobs = function(which = NULL, topJob=NULL) {
    if (!is.null(which)) {
        if ( length(which) != 1 || ! (is.numeric(which) || is.character(which)))
            stop("Must specify 'which' as an integer queue number or character scalar job type")
        which = as.character(which)
    }
    MOTUS_QUEUE <<- NULL

    ## connect the global Jobs object to the MOTUS_SERVER_DB's jobs table
    Jobs <<- Copse(MOTUS_SERVER_DB, "jobs", type=character(), done=integer(), queue=character(), path=character(), oldpath=character(), user=character())

    if (is.null(which) && is.null(topJob))
        return()

    ## get IDs of jobs of selected type

    j = integer(0)
    if (is.character(which)) {
        ## by queue name
        j = query(Jobs,
                  paste0("select t1.id from jobs as t1 left join jobs as t2 on t1.stump=t2.id where t1.done = 0 and t2.queue='",  which, "'"))[[1]]
    }

    if (! is.null(topJob)) {
        topJob = as.integer(topJob)[1]
        if (! is.na(topJob)) {
            ## by id of topJob
            j = c(j, query(Jobs,
                           paste0("select t1.id from jobs as t1 where t1.done = 0 and t1.stump=",  topJob))[[1]]
                  )
        }
    }

    ## correct paths in case server was interrupted after recording new path but before moving job,
    ## and enqueue jobs

    for (i in j) {
        if (! file.exists(Jobs[[i]]$path) && file.exists(Jobs[[i]]$oldpath))
            Jobs[[i]]$path = Jobs[[i]]$oldpath
        queueJob(Jobs[[i]])
    }
    return(length(j))
}
