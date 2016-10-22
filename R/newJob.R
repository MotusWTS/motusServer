#' create a new job
#'
#' @details
#'
#' A job is a Twig object from the Copse created by
#' \link{\code{loadJobs}}, and possibly an associated folder named NNNNNNNN,
#' where N is the job number padded on the left with zeroes to a
#' length of 8 digits.  Files associated with the job are stored in
#' the folder, while metadata are stored in the Twig object, which is
#' maintained in persistent storage in the Copse's SQLite database.
#' Jobs can have subjobs via the Twig's parent() relationship.
#'
#' @param type character scalar name of job type
#'
#' @param path to the folder in which to create the new job's folder.
#' If omitted, no path is created for this job, and the job's \code{$path}
#' item is set to the \code{.parent$path}, if \code{.parent} is not null.
#'
#' @param ...  additional named metadata for this job
#'
#' @param parent .parent job, if any
#'
#' @return A Twig (see \link{\code{Copse}}) object \code{j} representing the job.
#'     The path to the job folder is accessible as \code{j$dir}.
#'
#' @export
#'
#' @seealso \link{\code{Copse}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

newJob = function(type, path, ..., .parent=NULL) {
    rv = newTwig(Jobs, type=type, done=FALSE, ..., .parent=.parent)
    if (! missing(path)) {
        np = file.path(path, sprintf("%08d", rv))
        rv$path = np
        dir.create(np, recursive=TRUE, mode=MOTUS_DEFAULT_FILEMODE)
    } else if (!is.null(.parent)) {
        rv$path = .parent$path
    }
    return(rv)
}
