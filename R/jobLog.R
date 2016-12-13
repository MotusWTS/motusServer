#' Add a message to the log for a job.  Log messages are saved in a
#' JSON field called "log" in the top-level ancestor of the job.
#'
#' @param j the job
#'
#' @param msg character vector of messages
#'
#' The messages in \code{msg} are joined with "\\n" and appended to any already existing for this job.
#'
#' @export

jobLog = function(j, msg) {
    if (!inherits(j, "Twig"))
        stop("jobLog: j must have class 'Twig'")
    C = copse(j)
    C$sql(paste0("update ", C$table, " set data=json_set(data, '$.log', ifnull(json_extract(data, '$.log'), '') || :msg) where id=", stump(j)),
          msg = paste(msg, "\n", collapse="", sep=""))
}
