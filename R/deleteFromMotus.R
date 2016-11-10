#' delete a set of detections from motus by adding records
#' to the batchDelete table.
#'
#' @details detections are added or removed from motus in batches.  For
#' Lotek receivers, a batch is a sequence of all detections in a range
#' of timestamps.  For an SG receiver, a batch is additionally constrained
#' to be within a single boot session.  Boot sessions can cover multiple
#' batches, however.
#'
#' The batches deleted will be:
#' \enumerate{
#' \item Lotek receiver: all batches satisfying the tsStart and/or tsEnd
#' constraints, whichever are specified, are deleted.  If neither tsStart
#' nor tsEnd is specified, all batches for this receiver are deleted.
#' \item SG receiver: all batches with the specified monoBN and satsifying
#' any specified tsStart / tsEnd constraints are deleted.  If neither
#' tsStart nor tsEnd is specified, all batches for this receiver and
#' boot session are deleted.
#' }
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param reason character scalar giving reason for deletion, in human-readable form
#'
#' @param monoBN boot session number; required if an SG receiver; omit
#'     or set to NULL for a Lotek receiver.
#'
#' @param tsStart starting timestamp; if specified, only those batches
#' containing at least 1 detection with timestamp >= tsStart are deleted
#'
#' @param tsEnd ending timestamp; if specified, only those batches
#' containing at least 1 detection with timestamps <= tsEnd are deleted
#'
#' @return TRUE on success; FALSE otherwise
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

deleteFromMotus = function(src, reason="not given", monoBN=NULL, tsStart=0, tsEnd=1e11) {

    meta = getMap(src)
    isSG = meta$recvType == "SG"
    if (isSG && is.null(monoBN))
        stop("Must specify monoBN for SG receiver")

    con = src$con
    sql = function(...) dbGetQuery(con, sprintf(...))

    ## find out what's in the transfer tables
    motusTX = tbl(src, "motusTX")

    ## open the motus transfer table

    mt = openMotusDB()
    mtcon = mt$con
    mtsql = function(...) dbGetQuery(mtcon, sprintf(...))

    ## find all batches satisfying the specifications

    bn = mtsql("select batchID from batches where %s tsEnd >= %.14g and tsStart <= %.14g order by batchID",
                   if (isSG) sprintf("monoBN=%d and ", monoBN) else "", tsStart, tsEnd) [[1]]

    ## mark batches as having been deleted by negating the ID field, but make sure we're not adding a duplicated negated batchID
    ## FIXME: why are we doing this weirdness?

    sql("update motusTX set batchID=-batchID where batchID in (%s) and not batchID in (select -batchID from motusTX where batchID < 0)", paste(bn, collapse=","))

    ## record all groups of consecutive batches to be deleted

    now = as.numeric(Sys.time())
    while(length(bn) > 0) {
        ## find the first non-consecutive gap
        j = which(diff(bn) > 1)[1]
        if (is.na(j))
            j = length(bn)
        mtsql("insert into batchDelete (batchIDbegin, batchIDend, ts, reason, tsMotus)
                                values (%d, %d, %f, '%s', 0)",
              bn[1], bn[j], now, gsub("'", "''", reason, fixed=TRUE))
        bn = bn[-(1:j)]
    }
    return(TRUE)
}
