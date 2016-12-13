#' get the filesystem path for a job
#'
#' @details
#'
#' If a job has a filesystem folder, its path is a non-null character string
#' giving the path to that folder relative to the path to its parent job.
#'
#' If the job does not have a filesystem folder, this function returns the
#' path of the most recent ancestor which does have a filesystem folder.
#'
#' This function uses an SQLite recursive common table entity query to
#' generate the path on the fly from the \code{$path} components of
#' this jobs and its ancestors.  This traces the job up to its top job,
#' pre-pending non-null path components as it goes.
#'
#' @param j the job
#'
#' @return A character scalar giving the full path to the job's folder, or
#' to the most recent ancestor's folder if this job doesn't have one.
#' To test whether a job has a folder, use \link{\code{jobHasFolder()}}
#'
#' @export
#'
#' @seealso \link{\code{Copse}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

jobPath = function(j) {
    query(Jobs, paste0("
with recursive elders(path, pid) as (select path, pid from jobs where id=",
as.integer(j), "
union all
select coalesce(t1.path || '/' || t2.path, t2.path, t1.path), t1.pid
from jobs as t1 join elders as t2 on t2.pid=t1.id where t2.pid is not null)
select path from elders where pid is null;
"))[[1]]
}
