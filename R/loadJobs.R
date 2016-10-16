#' load existing jobs from server database
#'
#' A global object \code{Jobs} is created, which manages jobs.
#' It is populated from the "jobs" table in the server database.
#'
#' @return no return value.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

loadJobs = function() {
    Jobs <<- Copse(MOTUS_SERVER_DB, "jobs", type=character(), done=integer(), path=character())
}
