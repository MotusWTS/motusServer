#' Get the src_sqlite for a receiver database given its serial number.
#'
#' receiver database files are stored in a single directory, and
#' have names like "SG-XXXXBBBKYYYY.motus" or "Lotek-NNNNN.motus"
#'
#' @param serno receiver serial number
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{MOTUS_PATH$RECV}
#'
#' @param busyTimeout total amount of time to allow being spent retrying
#' a busy database, in seconds.  Default:  300 = 5 minutes.
#'
#' @return a src_sqlite for the receiver; if the receiver is new, this database
#' will be empty, but have the correct schema.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getRecvSrc = function(serno, dbdir = MOTUS_PATH$RECV, busyTimeout=300) {
    src = src_sqlite(file.path(dbdir, paste0(serno, ".motus")), TRUE)
    dbGetQuery(src$con, sprintf("pragma busy_timeout=%d", round(busyTimeout * 1000)))
    ensureRecvDBTables(src, serno=serno)
    return(src)
}
