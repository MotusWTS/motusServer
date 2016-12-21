#' ensure we have created the server database
#'
#' This database holds a table of symbolic locks (e.g. to prevent multiple
#' processes from running a job on the same receiver in parallel)
#' It also holds all job information in table \code{jobs}, but that
#' table is ensured by the call to \link{\code{Copse()}} in \link{\code{loadJobs()}}
#'
#' @return no return value, but saves a safeSQL connection to the server database
#' in the global symbol \code{ServerDB}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureServerDB = function() {
    if (exists("ServerDB", .GlobalEnv))
        return()
    ServerDB <<- safeSQL(MOTUS_SERVER_DB)
    ServerDB(sprintf("CREATE TABLE IF NOT EXISTS %s (
symbol TEXT UNIQUE PRIMARY KEY,
owner INTEGER
)" ,
MOTUS_SYMBOLIC_LOCK_TABLE))
    return(invisible(NULL))
}
