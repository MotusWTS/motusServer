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
#' @param vacuum boolean; if TRUE (the default), free unused storage
#' from the database.  This can be slow, as the entire database is
#' rewritten.
#' 
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

cleanup = function(src, dropTables = FALSE, vacuum=FALSE) {
    sql = function(...) dbGetQuery(src$con, sprintf(...))
    for (t in c("batches", "runs", "hits", "batchParams", "batchProgs", "batchState", "gps", "tagAmbig", "timeFixes", "pulseCounts"))
        sql("%s %s", if (dropTables) "drop table if exists" else "delete from", t)
    if (dropTables)
        sgEnsureDBTables(src)
    if (vacuum) {
        sql("pragma page_size=4096") ## use a page size that's good for modern hard drives
        sql("vacuum")
    }
}

    
