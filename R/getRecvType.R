#' determine the receiverType from a serial number
#'
#' @param serno character scalar; receiver serial number, e.g. "Lotek-123"
#'
#' @param lotekModel logical; if TRUE (the default), include the model if the receiver
#' is a Lotek.  Otherwise, return just "LOTEK" for such receivers.
#'
#' @return a character scalar with the receiverType, suitable for use
#' with \code{motusRegisterReceiver()}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getRecvType = function(serno, lotekModel=TRUE) {
    if (substr(toupper(serno), 1, 5) == "LOTEK") {
        if (model)
            return(paste0("LOTEK", getRecvModel(serno)))
        else
            return("LOTEK")
    }
    return ("SENSORGNOME")
}
