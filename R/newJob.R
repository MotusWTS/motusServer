#' create a new job
#'
#' @details
#'
#' A job is a Twig object from the Copse created by
#' \link{\code{loadJobs}}, and an associated folder named NNNNNNNN,
#' where N is the job number padded on the left with zeroes to a
#' length of 8 digits.  Files associated with the job are stored in
#' the folder, while metadata are stored in the Twig object, which is
#' maintained in persistent storage in the Copse's SQLite database.
#' Jobs can have subjobs via the Twig's parent() relationship.
#'
#'
#' @param path to the folder in which to create the new job's folder
#'
#' @param type character scalar name of job handler
#'
#' @param params list of parameters for this job
#'
#' @param ...  additional named metadata for this job
#'
#' @param parent .parent job, if any
#'
#' @return A Twig object (see \link{\code{Copse}}) representing the job.
#'     with class "motusJob".  The value is the job number, and the
#'     name is the full path to the new folder.
#'
#' @export
#'
#' @seealso \link{\code{Copse}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

newJob = function(path, type, params, ..., .parent=NULL) {
    rv = newTwig(Jobs, type=type, params=params, ..., .parent=.parent)
    np = file.path(path, sprintf("%08d", twigID(rv)))
    rv$dir = np
    return(rv)
}
