#' Delete all data for this receiver from ths motus transfer tables.
#'
#' Deletes all records in all tables of the motus transfer database that
#' relate to this receiver. This should only be done very rarely.
#' e.g. during development/testing.  Normally, if a batch needs to be
#' re-run for some reason, the formal batchDelete mechanism should be
#' used, so that an audit trail is left.
#' 
#' @param src dplyr src_sqlite to receiver database
#'
#' @return no return value.
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

purgeFromMotus = function(src) {
    deviceID = getMotusDeviceID(src)

    ## open the motus transfer table
    
    mt = openMotusDB()
    mtcon = mt$con
    mtsql = function(...) dbGetQuery(mtcon, sprintf(...))

    bdrop = mtsql("select batchID from batches where motusRecvID=%d", deviceID)
    if (nrow(bdrop) > 0) {

        bdrop = paste(bdrop[[1]], collapse=",")

        ## drop related records from tables.  To maintain referential integrity
        ## while dropping, we must do batches last, and runs after hits.
        
        for (t in c("gps", "runUpdates", "hits", "batchAmbig", "batchProgs", "batchParams"))
            mtsql("delete from %s where batchID in (%s)", t, bdrop)

        mtsql("delete from runs where batchIDbegin in (%s)", bdrop)
        mtsql("delete from batches where batchID in (%s)", bdrop)
    }
    dbDisconnect(mtcon)

    ## remove any record of having transferred data to motus
    dbGetQuery(src$con, "delete from motusTX")
}