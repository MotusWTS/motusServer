#' determine the receiverType from a serial number
#'
#' @param serno character scalar; receiver serial number, e.g. "Lotek-123"
#'
#' @return a character scalar with the receiverType, suitable for use
#' with \code{motusRegisterReceiver()}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getRecvType = function(serno, extra) {
    if (substr(toupper(serno), 1, 5) == "LOTEK") {
        return(paste0("LOTEK", getLotekModel(serno)))
    }
    return ("SENSORGNOME")
}
