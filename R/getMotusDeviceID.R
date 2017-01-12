#' Get the motus device ID for a receiver, given its database.
#'
#' @param src dplyr src_sqlite to receiver database
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
    ## try get this information from the receiver database.
    m = getMap(src)
    deviceID = m$deviceID
    if (isTRUE(deviceID > 0))
        return(as.integer(deviceID))

    ## see whether motus knows this receiver
    mm = motusListSensors(serialNo=m$recvSerno)
    if (length(mm) > 0) {
        if (nrow(mm) == 1 || (nrow(mm) > 0 && useFirst)) {
            m$deviceID = mm$deviceID[match(m$recvSerno, mm$serno)][1]
            return(as.integer(m$deviceID))
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
