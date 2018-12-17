#' ensure we have created the server database
#'
#' This database holds a table of symbolic locks (e.g. to prevent multiple
#' processes from running a job on the same receiver in parallel)
#' It also holds all job information in table \code{jobs}, but that
#' table is ensured by the call to \link{\code{Copse()}} in \link{\code{loadJobs()}}
#'
#' @param installing; logical scalar; if TRUE, the caller is part of
#' package installation, rather than a running server, and the locking
#' of the `ServerDB` symbol is skipped.  Default:  FALSE
#'
#' @return no return value, but saves a safeSQL connection to the server database
#' in the global symbol \code{ServerDB}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureServerDB = function(installing=FALSE) {
    if (exists("ServerDB", .GlobalEnv))
        return()

    ServerDB <<- safeSQL(MOTUS_PATH$SERVER_DB)

    if (! installing) {
        lockSymbol("ServerDB")
        on.exit(lockSymbol("ServerDB", lock=FALSE))
    }

    ServerDB(sprintf("CREATE TABLE IF NOT EXISTS %s (
symbol TEXT UNIQUE PRIMARY KEY,
owner INTEGER
)" ,
MOTUS_SYMBOLIC_LOCK_TABLE))

    ServerDB("
CREATE TABLE IF NOT EXISTS products (
    productID INTEGER UNIQUE PRIMARY KEY, -- unique identifier for this product
    jobID INTEGER NOT NULL,               -- ID of top-level processing job which generated this product
    URL TEXT,                             -- URL at which product can be found
    serno VARCHAR(32),                    -- receiver serial number, if any, associated with product
    projectID INTEGER                     -- motus ID of project, if any, that owns the product
)")
    ServerDB("CREATE INDEX IF NOT EXISTS products_serno on products(serno)")
    ServerDB("CREATE INDEX IF NOT EXISTS products_projectID on products(projectID)")

    return(invisible(NULL))
}
