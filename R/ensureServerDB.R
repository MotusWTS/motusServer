#' ensure we have created the server database
#'
#' this database holds a table of receiver locks (to prevent multiple
#' processes from running a job on the same receiver in parallel)
#'
#' @return safeSQL connection to the server database.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureServerDB = function() {
    sql = safeSQL(MOTUS_SERVER_DB)
    ## 10 second busy-timeout
    sql("PRAGMA busy_timeout=10000")
    sql(sprintf("CREATE TABLE IF NOT EXISTS %s (
serno TEXT UNIQUE PRIMARY KEY,
procNum INTEGER
)" ,
MOTUS_RECEIVER_LOCK_TABLE))
    return (sql)
}
