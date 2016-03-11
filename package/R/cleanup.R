#' remove old processed data from a receiver database.
#'
#' This deletes all output and record of processing.  Original
#' raw data is not affected.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

cleanup = function(src) {
    sql = function(...) dbGetQuery(src$con, sprintf(...))
    for (t in c("batches", "runs", "hits", "batchParams", "batchProgs", "batchState"))
        sql("delete from %s", t)
    sql("vacuum")
}

    
