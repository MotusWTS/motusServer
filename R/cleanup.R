#' remove old processed data from a receiver database.
#'
#' This deletes all output and record of processing.  Original
#' raw data is not affected.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param dropTables boolean; if TRUE, erase all output tables, rather
#' than just emptying them.  This makes sense if their schema
#' has changed, but is usually not required, so the default is FALSE.
#'
#' @param vacuum boolean; if TRUE, free unused storage
#' from the database.  This can be slow, as the entire database is
#' rewritten.  Default: \code{dropFiles}, so normally FALSE.
#'
#' @param dropFiles boolean; if TRUE, also delete all raw data files
#'     and information about them which are stored in the DB.
#'     WARNING: do not do this unless you have copies of the files
#'     stored elsewhere, e.g. in \code{MOTUS_PATH$file_repo}.
#'     Default: FALSE.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

cleanup = function(src, dropTables = FALSE, vacuum=dropFiles, dropFiles=FALSE) {
    sql = function(...) dbGetQuery(src$con, sprintf(...))
    haveTables = dbListTables(src$con)
    tablesToEmpty = c("batches", "runs", "hits", "batchParams", "batchProgs", "batchState", "batchRuns", "gps", "tagAmbig", "timeFixes", "pulseCounts", "motusTX")
    if (dropFiles)
        tablesToEmpty = c(tablesToEmpty, "files", "fileContents", "DTAfiles", "DTAlines")
    tablesToEmpty = tablesToEmpty[tablesToEmpty %in% haveTables]
    for (t in tablesToEmpty)
        sql("%s %s", if (dropTables) "drop table if exists" else "delete from", t)
    if (dropTables)
        sgEnsureDBTables(src)
    if (vacuum) {
        sql("pragma page_size=4096") ## use a page size that's good for modern hard drives
        sql("vacuum")
    }
}
