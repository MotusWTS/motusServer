#' ensure we have created the server database
#'
#' This database holds a table of symbolic locks (e.g. to prevent multiple
#' processes from running a job on the same receiver in parallel)
#'
#' @return safeSQL connection to the server database.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureServerDB = function() {
    sql = safeSQL(MOTUS_SERVER_DB)
    sql(sprintf("CREATE TABLE IF NOT EXISTS %s (
symbol TEXT UNIQUE PRIMARY KEY,
owner INTEGER
)" ,
MOTUS_SYMBOLIC_LOCK_TABLE))
    return (sql)
}
