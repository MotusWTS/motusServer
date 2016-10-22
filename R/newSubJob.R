#' create a new subjob of an existing job
#'
#' The subjob gets the existing job as parent, and will be of
#' the same type.  The subjob's folder is created inside the
#' parent's folder.
#'
#' @param j existing job
#'
#' @param type character scalar of type of subjob
#'
#' @param ...  additional named metadata for this job
#'
#' @return A Twig (see \link{\code{Copse}}) object \code{j} representing the job.
#'     The path to the job folder is accessible as \code{j$path}.
#'
#' @export
#'
#' @seealso \link{\code{Copse}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

newSubJob = function(j, type, ...) {
    newJob(type=type, ..., .parent=j)
}
