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

    ## open the motus transfer DB

    openMotusDB()

    bdrop = MotusDB("select batchID from batches where motusDeviceID=%d", deviceID)
    if (nrow(bdrop) > 0) {

        bdrop = DBI::SQL(paste(bdrop[[1]], collapse=","))

        ## drop related records from tables.  To maintain referential integrity
        ## while dropping, we must do batches last, and runs after hits.

        for (t in c("gps", "runUpdates", "hits", "batchProgs", "batchParams"))
            MotusDB("delete from %s where batchID in (%s)", t, bdrop)

        MotusDB("delete from runs where batchIDbegin in (%s)", bdrop)
        MotusDB("delete from batches where batchID in (%s)", bdrop)
    }

    ## remove any record of having transferred data to motus
    dbGetQuery(src$con, "delete from motusTX")
}
