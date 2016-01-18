#' extract GPS fixes from an SG stream
#'
#' A stream is the ordered sequence of raw data files from a receiver
#' corresponding to a single boot session (period between restarts).
#' This function parses out GPS fixes, which look like
#' 
#' \code{G,14523444.23,45.2342,-65.1234,233}
#'
#' and adds them to the gps table in the receiver database.  GPS fixes
#' in the stream having the same timestamp as a fix already in
#' the table are silently ignored.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param mbn integer monotonic boot number; this is the monoBN field
#'     from the \code{files} table in the receiver's sqlite database.
#'     Defaults to NULL, meaning process GPS fixes for all streams.
#' 
#' @return the number of GPS fixes parsed; the number actually added
#'     to the table might be smaller.
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgGetGPSfixes = function(src, mbn = NULL) {
    ## create user context
    u = new.env(emptyenv())
    
    ## run the worker on the stream(s)
    g = sgRunStream(src, sgGetGPSfixesWorker, mbn, u)
    if (length(g) > 0) {
        ## convert list to single matrix
        g = do.call(rbind, g)
        if (nrow(g) > 0) {
            ## add to database table
            dbGetPreparedQuery(src$con,
                               "insert or ignore into gps (ts, lat, lon, alt) values (:ts, :lat, :lon, :alt)",
                               data_frame(ts = g[, 1], lat = g[, 2], lon = g[, 3], alt = g[, 4]) %>% as.data.frame
                               )
        }
        return(nrow(g))
    }
    return(0)
}
