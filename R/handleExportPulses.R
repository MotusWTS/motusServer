#' create an interim .sqlite file with tables of pulses and antenna parameters
#'
#' For now, beeper tags are supported by generating an .sqlite file with
#' pulses and parameter settings because the tag finder doesn't yet
#' support assembling runs of pulses from a beeper tag.
#'
#' @param j the job, with these fields:
#' \itemize{
#' \item serno - the receiver serial number
#' \item batchID - the batchID for which to export pulses
#' }
#'
#' @return TRUE
#'
#' @details The data are written to tables 'pulses' and 'params' in an sqlite
#' file.  The sqlite file is stored in the download folder for the project
#' owning the batch.  This is given by \code{file.path(MOTUS_PATH$WWW,motusProjectID}
#' The file has a name like `SG-1234BBBK5678_beeper.sqlite`.
#'
#' Schemas for the tables are copied from the receiver database tables
#' `params` and `pulses`.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleExportPulses = function(j) {
    serno = j$serno
    batchID = j$batchID
    lockSymbol(serno)

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockSymbol(serno, lock=FALSE))

    isTesting = isTRUE(topJob(j)$isTesting)
    outDir = productsDir(serno, isTesting)

    src = getRecvSrc(serno)
    sql = safeSQL(src)
    projectID = sql("select motusProjectID from batches where batchID=%d", batchID)[[1]]

    out = file.path(outDir, sprintf("%s_beeper.sqlite", serno))

    ## we'll copy directly from tables in the receiver DB to the output DB
    sql("ATTACH DATABASE '%s' as d", out)
    ## if necessary, create the target database schema to match the source
    sqliteCloneIntoDB(sql, 'params', 'd')
    sqliteCloneIntoDB(sql, 'pulses', 'd')
    sql("INSERT OR REPLACE INTO d.params select * from params where batchID=%d", batchID)
    sql("INSERT OR REPLACE INTO d.pulses select * from pulses where batchID=%d", batchID)

    sql("DETACH DATABASE d");
    closeRecvSrc(src)
    registerProducts(j, out, projectID=projectID, isTesting=isTesting)
    return (TRUE)
}

#' clone an sqlite table schema (including indexes) from the main DB into an attached DB
#' @param sql safeSQL object to sqlite database
#' @param tableName character; name of table in main database which should be cloned
#'   into attached database
#' @param dbName name of attached DB; i.e. the 'D' from a statement
#' like `attach database 'blam.sqlite' as D`.  The database must already have
#' been attached by the caller.
#'
#' @details creates the empty table with the same key and with any associated indexes,
#' but only if a table (and/or indexes) of the same name don't already exist in the
#' attached db.

sqliteCloneIntoDB = function(sql, tableName, dbName) {
    if (!inherits(sql$con, "SQLiteConnection"))
        stop("sql must be a safeSQL object for an sqlite database")
    scm = sql("SELECT sql FROM sqlite_master WHERE type='table' and name='%s'", tableName)
    scm = sub("^create table ", sprintf("create table if not exists %s.", dbName), scm, ignore.case=TRUE)
    sql(scm)
    ndx = sql("SELECT sql FROM sqlite_master WHERE type<>'table' and tbl_name='%s'", tableName)
    for (i in ndx$sql) {
        scm = sub("index[[:space:]]+([^[:space:]]+)[[:space:]]+on[[:space:]]+",
                  sprintf("index if not exists %s.\\1 on ", dbName), i, perl=TRUE, ignore.case=TRUE)
        sql(scm)
    }
}
