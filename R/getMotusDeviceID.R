#' Get the motus device ID for a receiver, given its database.
#'
#' @param src dplyr src_sqlite to receiver database, or a character
#' serial number
#'
#' @param useFirst if TRUE, the first receiver matching the given
#' serial number is used. if FALSE and more than one
#' receiver matches, fail with an error.
#'
#' @return the sensor ID, an integer
#'
#' @note As a side-effect, the motus device ID is also stored in the
#' receiver database "meta" table, with key "deviceID"
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getMotusDeviceID = function(src, useFirst=FALSE) {
    if (! inherits(src, "src"))
        src = getRecvSrc(src)

    ## try get this information from the receiver database.
    m = getMap(src)
    deviceID = as.integer(m$deviceID)
    if (isTRUE(deviceID > 0))
        return(deviceID)

    ## see whether motus knows this receiver
    mm = MetaDB("select distinct deviceID from recvDeps where deviceID IS NOT NULL and serno=:serno", serno=m$recvSerno)
    if (nrow(mm) > 0) {
        if (nrow(mm) == 1 || (nrow(mm) > 0 && useFirst)) {
            m$deviceID = mm$deviceID[1]
            rv = as.integer(m$deviceID)
            if (isTRUE(rv > 0))
                return(rv)
        } else {
            stop("More than one registered receiver has this serial number; motusIDs are:\n", capture.output(mm))
        }
    }

    ## try register this receiver
    m$deviceID = motusRegisterReceiver(m$recvSerno)$deviceID

    return(as.integer(m$deviceID))
}
