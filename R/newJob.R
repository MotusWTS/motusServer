#' create and enqueue a new job
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
#' @param .type character scalar name of job type
#'
#' @param .parentPath the folder in which to create the new job's folder.
#' If omitted, no folder is created for this job, and the job's \code{$path}
#' item is set to NULL.  If .parentPath is specified as NULL, then the
#' new job's path is just its formatted id number.  Otherwise, the job's path
#' is \code{.parentPath} followed by "/" and the job's formatted ID.
#'
#' @param ...  additional named metadata for this job
#'
#' @param .parent .parent job, if any
#'
#' @param .enqueue logical scalar; should the job be added to the current queue?
#' Default: TRUE, but non-server callers such as scripts should specify
#' FALSE.
#'
#' @return A Twig (see \link{\code{Copse}}) object \code{j} representing the job.
#'     The path to the job folder is accessible as \code{j$dir}.
#'
#' @export
#'
#' @seealso \link{\code{Copse}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

newJob = function(.type, .parentPath, ..., .parent=NULL, .enqueue=TRUE) {
    j = newTwig(Jobs, type=.type, done=FALSE, ..., .parent=.parent)
    if (! missing(.parentPath)) {
        j$path = do.call('file.path', c(list(), .parentPath, sprintf("%08d", j)))
        dir.create(jobPath(j), recursive=TRUE, mode=MOTUS_DEFAULT_FILEMODE)
    }
    if (.enqueue)
        queueJob(j)
    return(j)
}
