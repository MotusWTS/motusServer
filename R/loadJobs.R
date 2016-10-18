#' load existing jobs from server database
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
#' For any jobs which are not done and which are of the specified
#' type, we verify that the "path" field is correct, in case the
#' server was interrupted while moving a job.
#'
#' @param stumpType only examine jobs whose stump is of the specified type.
#'
#' @return no return value.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

loadJobs = function(stumpType) {
    Jobs <<- Copse(MOTUS_SERVER_DB, "jobs", type=character(), done=integer(), path=character(), oldpath=character())

    j = query(Jobs,
              paste0("select t1.id from jobs as t1 left join jobs as t2 on t1.stump=t2.id where (not t1.done) and ((t2.id is NULL and t1.type=='", stumpType,"') or t2.type=='", stumpType, "')"))[[1]]
    for (i in j) {
        if (! file.exists(Jobs[[i]]$path) && file.exists(Jobs[[i]]$oldpath))
            Jobs[[i]]$path = Jobs[[i]]$oldpath
    }
}
