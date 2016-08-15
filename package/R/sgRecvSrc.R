#' Get the src_sqlite for a receiver database given its serial number.
#'
#' receiver database files are stored in a single directory, and
#' have names like "SG-XXXXBBBKYYYY.motus".
#'
#' @param serno raw sensorgnome serial number (i.e. without "SG-")
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{/sgm/recv}
#'
#' @return a src_sqlite for the receiver; if the receiver is new, this database
#' will be empty, but have the correct schema.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgRecvSrc = function(serno, dbdir = "/sgm/recv") {
    src = src_sqlite(file.path(dbdir, paste0("SG-", serno, ".motus")), TRUE)
    sgEnsureDBTables(src)
    return(src)
}
