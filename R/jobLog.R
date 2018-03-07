#' Add a message to the log for a job.  Log messages are saved in either the
#' "summary_" field in the top-level ancestor of the job (for summary messages), or in the job's own
#' "log_" field, for detailed messages.
#'
#' @param j the job
#'
#' @param msg character vector of messages
#'
#' @param summary logical scalar; if TRUE, the message is added to the summary field; otherwise,
#' the default, it is added to the log field.
#'
#' @return \code{invisible(NULL)}
#'
#' The messages in \code{msg} are joined with "\\n" and appended to any already existing for this job.
#'
#' @export

jobLog = function(j, msg, summary=FALSE) {
    if (!inherits(j, "Twig"))
        stop("jobLog: j must have class 'Twig'")
    C = copse(j)
    field = ifelse(isTRUE(summary), "summary_", "log_")
    jobid = if (summary) stump(j) else j
    C$sql(paste0("update ", C$table, " set data=json_set(ifnull(data, '{}'), '$.", field, "', ifnull(json_extract(data, '$.", field, "'), '') || :msg) where id=", jobid),
          msg = paste(msg, "\n", collapse="", sep=""))
    return(invisible(NULL))
}
