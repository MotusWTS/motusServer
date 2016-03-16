#' parse sensorgnome filenames into components
#' 
#' @param f: character vector of filenames with full path
#'
#' @return a dataframe of components, with one row per filename and these columns:
#'
#' \enumerate{
#'  \item "prefix":  human readable short site name
#'  \item "serno":  receiver serial number; 12 alphanumeric characters e.g. 1315BBBK2156
#'  \item "macAddr": 12 byte hex mac address (lower case); NA if not available
#'  \item "bootnum":  boot count (integer)
#'  \item "ts":  timestamp embedded in name (double, with class \code{c("POSIXt", "POSIXct")} )
#'  \item "tsCode":  timestamp code ('P' means before GPS fix, 'Z' means accurate to 1e-6 s, 'Y' to 1e-5s, 'X' to 1e-4s, ..., 'T' to 1s)
#'  \item "port":  port number, if this file is associated with a single port (e.g. a .WAV file); NA if all ports
#'  \item "extension":  extension of uncompressed file; e.g. ".txt"
#'  \item "comp":  integer; file compression type":  NA = uncompressed, 1 = gzip, 2 = lzip
#'
#' }
#' @note Returns NULL if no filenames match regex; otherwise, return value has rows
#' filled with NA for any filenames not matching regex
#' 
#' @export

parseFilenames = function(f) {
    rv = splitToDF(sgFilenameRegex, f, as.is=TRUE, validOnly=FALSE)
    if (is.null(rv))
        return(rv)
    rv$ts = ymd_hms(rv$ts)
    return(rv)
}
