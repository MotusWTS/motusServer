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

getMotusDeviceID = function(src, useFirst=TRUE) {
    if (! inherits(src, "src"))
        src = getRecvSrc(src)

    ## try get this information from the receiver database.
    m = getMap(src)
    deviceID = m$deviceID
    if (isTRUE(deviceID > 0))
        return(as.integer(deviceID))

    ## see whether motus knows this receiver
    mm = MetaDB("select deviceID from recvDeps where serno=:serno", serno=m$recvSerno)
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
    motusRegisterReceiver(m$recvSerno)

    ## read back the ID of the newly-registered receiver
    ## (the API call above doesn't return the ID)

    mm = motusListSensors(serialNo=m$recvSerno)
    m$deviceID = mm$id
    return(mm$id)
}
