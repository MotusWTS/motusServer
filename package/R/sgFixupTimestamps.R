#' Correct timestamps for a batch of tag detections
#'
#' After running the tag finder on a batch, there might be a new
#' record in the timeJumps table, corresponding to a delayed setting
#' of system time from the GPS.  This function corrects timestamps of
#' any hits from before that setting.  It also notes this fact
#' in the timeFixes table.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param batchID number of batch in which to correct timestamps. Default,
#' NULL, means the latest batch.
#'
#' @return TRUE if any timestamps were corrected; FALSE otherwise.
#' 
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgFixupTimestamps = function(src, batchID = NULL) {
    sql = function(...) dbGetQuery(src$con, sprintf(...))

    if (is.null(batchID))
        batchID = sql("select max(batchID) from batches") [[1]]
    
    jumps = sql("select * from timeJumps where batchID == %d", batchID)

    if (nrow(jumps) == 0)
        return(FALSE)

    if (nrow(jumps) > 1) {
        warning("multiple timeJumps in raw data for this batch; possible receiver GPS problem\nSource: ", src$path, "\nBatch: ", batchID)
        jumps = jumps[1,]
    }
    
    offset = jumps$tsAfter - jumps$tsBefore

    
    BBbootTime = as.numeric(ymd("2000-01-01"))

    ## the range of times to be corrected depends on the correction type

    correctRange = switch(jumps$jumpType,
                          S = c(BBbootTime, jumps$tsBefore), ## correct times before the GPS time set
                          M = c(         0, BBbootTime)      ## correct monotonic times
                          )

    ## lower limit of times corrected also depends on it.
    
    ## correct hits
    sql("update hits set ts=ts + %.4f where ts <= %.4f and batchID = %d",
        offset, correctRange[2], batchID)

    ## correct batch start timestamps
    sql("update batches set tsBegin=tsBegin + %.4f where tsBegin <= %.4f and batchID = %d",
        offset, correctRange[2], batchID)

    ## correct batch end timestamps (this could happen if the time
    ## jump occurred after the last tag detection)
    
    sql("update batches set tsEnd=tsEnd + %.4f where tsEnd <= %.4f and batchID = %d",
        offset, correctRange[2], batchID)

    comment = switch(jumps$jumpType,
                    S = 'GPS set',
                    M = 'GPS pin: monotonic clock',
                    jumps$jumpType)
        
    sql("insert into timeFixes (batchID, tsFixedLow, tsFixedHigh, tsFixedBy, comment) values (%d, %.4f, %.4f, %.4f, '%s')",
                                batchID, correctRange[1], correctRange[2], offset, comment)
    return(TRUE)
}
