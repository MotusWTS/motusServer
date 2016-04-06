#' Store the motus sensor ID into a receiver database.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param useFirst if TRUE, the first receiver matching the given
#' serial number and macAddr is used. if FALSE and more than one
#' receiver matches, fail with an error.
#'
#' @return the sensor ID, an integer
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getMotusSensorID = function(src, useFirst=TRUE) {
    ## try get this information from the receiver database.
    m = getMap(src, "meta")
    recvID = m$recvID
    if (length(recvID) > 0 && ! is.na(recvID))
        return(as.integer(recvID))

    ## see whether motus knows this receiver
    mm = motusListSensors(serialNo=m$recvSerno, macAddress=m$macAddr)
    if (nrow(mm) == 1 || (nrow(mm) > 0 && useFirst)) {
        m$recvID = mm$id[match(m$recvSerno, mm$serno)][1]
        return(as.integer(m$recvID))
    } else if (nrow(mm) > 0) {
        stop("More than one registered receiver has this serial number; motusIDs are:\n", capture.output(mm))
    }

    ## try register this receiver
    motusRegisterReceiver(m$recvSerno, m$macAddr)
    
    ## read back the ID of the newly-registered receiver
    ## (the API call above doesn't return the ID)

    mm = motusListSensors(serialNo=m$recvSerno, macAddress=m$macAddr)
    m$recvID = mm$id
    return(mm$id)
}
