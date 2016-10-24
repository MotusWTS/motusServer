#' try to accept a job for processing in a queue
#'
#' If the given job is still unclaimed, enter it into the specified
#' queue.  Subsequent attempts to claim the job will fail.  This
#' operation is atomic; i.e. if there are multiple instances of
#' processServer(), only one process will succeed in claiming the job.
#'
#' @param j the job (an integer of class "Twig")
#'
#' @param N integer queue number in the range 1..8
#'
#' @return TRUE if the job has been claimed, FALSE otherwise.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

claimJob = function(j, N) {
    ## SQLite obtains an exclusive lock on a table before starting an
    ## UPDATE query.  The 'WHERE' clause is evaluated after this lock is obtained,
    ## so that the following query operates as an atomic test-and-set.
    ## e.g. try the following:
    ##
    ##  sqlite3 /sgm/server.sqlite
    ##
    ##  sqlite> EXPLAIN UPDATE JOBS SET queue=8 WHERE id=9 AND queue=0;

    query(Jobs, paste0("update jobs set queue=", N, " where id=", j, " and queue=0"))
    if(isTRUE(N == j$queue)) {
        moveJob(j, MOTUS_PATH[[paste0("QUEUE", N)]])
        return (TRUE)
    }
    return (FALSE)
}
