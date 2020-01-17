#' determine the model from a receiver serial number
#'
#' The serial number determines the receiver model in most cases, but
#' for a few Lotek receivers, additional fields from a .DTA file are needed.
#' In those situations, the receiver DB would be examined for appropriate
#' fields in the meta table.
#'
#' @param serno character scalar; receiver serial number, e.g. "Lotek-123"
#'
#' @return a character scalar from this list:
#'
#' \itemize{
#'   \item SRX800D
#'   \item SRX400A
#'   \item SRX-DL
#'   \item SRX600
#'   \item SRX800M/MD
#'   \item SRX800
#'   \item BBW
#'   \item BBBK
#'   \item RPI2
#'   \item RPI3
#'   \item RPIZ
#'   \item UNKNOWN
#' }
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getRecvModel = function(serno) {
    serno = toupper(serno)
    if (substring(serno, 1, 3) == "SG-") {
        ## sensorgnome; basically just pull out  the middle 4 chars
        ## of the 12-character portion after "SG-", but treat BBW
        ## specially, as it might be followed by different characters
        model = toupper(substring(serno, 8, 11))
        if (model %in% c("BBBK", "RPI2", "RPI3", "RPIZ"))
            return(model)
        if (substring(model, 1, 3) == "BBW")
            return("BBW")
        return("UNKNOWN")
    } else if (substring(serno, 1, 7) == "LOTEK-") {
        ## get bare serial number by dropping "Lotek-" (first 6 chars)
        bareno = substring(serno, 7)
        ## drop any disambiguation suffix (e.g. "_1") as this is not
        ## relevant to model determination
        bareno = sub("_[0-9]$", "", bareno, perl=TRUE)

        ## map to model as per info from Lotek:

        ## > Yes, serial number uniquely identifies receiver.  All the SRX600
        ## > receiver serial numbers are 6###.  The SRX800 serial numbers start at 1.
        ## > It will be a long time before we get to 6000.  The old SRX400A models
        ## > were 9###A and up.
        ## ---
        ## > SRX-DL receivers have serial numbers 8###.

        ## and further:

        ## > As of June 1 2016 we decided to switch the SRX800 D
        ## > variant SN allocation to the format, D######,
        ## > i.e. D000426. This helps us distinguish a D variant
        ## > from a M / MD variant. The change in SN allocation
        ## > actually occurs from SN 000390 to SN D000391.

        if (substr(bareno, 1, 1) == "D") {
            model = "SRX800D"
        } else if (bareno >= "9000A") {
            model = "SRX400A"
        } else if (bareno >= "8000") {
            model = "SRX-DL"
        } else if (bareno >= "6000") {
            model = "SRX600"
        } else if (as.integer(bareno) >= 391) {
            ## per Lotek, it's not a model "D"
            model = "SRX800M/MD"
        } else {
            model = "SRX800"
        }
        return(model)
    } else {
        return("UNKNOWN")
    }
}
