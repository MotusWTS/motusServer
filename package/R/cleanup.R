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
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

cleanup = function(src, dropTables = FALSE) {
    sql = function(...) dbGetQuery(src$con, sprintf(...))
    for (t in c("batches", "runs", "hits", "batchParams", "batchProgs", "batchState", "gps"))
        sql("%s %s", if (dropTables) "drop table if exists" else "delete from", t)
    if (dropTables)
        sgEnsureDBTables(src)
    sql("vacuum")
}

    
