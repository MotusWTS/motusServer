#' ensure we have created the server database
#'
#' This database holds a table of symbolic locks (e.g. to prevent multiple
#' processes from running a job on the same receiver in parallel)
#' It also holds all job information in table \code{jobs}, but that
#' table is ensured by the call to \link{\code{Copse()}} in \link{\code{loadJobs()}}
#' And it holds a table of remotely-registered receivers and their credentials.
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

    lockSymbol("ServerDB")
    on.exit(lockSymbol("ServerDB", lock=FALSE))

    ServerDB(sprintf("CREATE TABLE IF NOT EXISTS %s (
symbol TEXT UNIQUE PRIMARY KEY,
owner INTEGER
)" ,
MOTUS_SYMBOLIC_LOCK_TABLE))

    ServerDB(sprintf("ATTACH DATABASE '%s' as remote", MOTUS_REMOTE_RECV_DB))

    ServerDB('
CREATE TABLE IF NOT EXISTS remote.receivers (
    serno        text unique primary key, -- only one entry per receiver
    creationdate real,                    -- timestamp when this entry was created
    tunnelport   integer unique,          -- port used on server for reverse tunnel back to sensorgnome
    pubkey       text,                    -- unique public/private key pair used by sensorgnome to login to server
    privkey      text,
    verified     integer default 0);      -- has receiver been verified?
')
    ServerDB('
CREATE TABLE IF NOT EXISTS remote.deleted_receivers (
    ts           real,                    -- deletion timestamp
    serno        text,                    -- possibly multiple entries per receiver
    creationdate real,                    -- timestamp when this entry was created
    tunnelport   integer,                 -- port used on server for reverse tunnel back to sensorgnome
    pubkey       text,                    -- unique public/private key pair used by sensorgnome to login to server
    privkey      text,
    verified     integer default 0        -- non-zero when verified
);
')
    return(invisible(NULL))
}
