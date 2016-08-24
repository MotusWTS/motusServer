#' parse sensorgnome filenames into components
#' 
#' @param f: character vector of filenames with full path
#'
#' @return a dataframe of components, with one row per filename and these columns:
#'
#' \enumerate{
#'  \item "prefix":  human readable short site name
#'  \item "serno":  receiver serial number; 12 alphanumeric characters e.g. 1315BBBK2156, or possibly with an appended "_N" where N is 1, 2, ...
#'  for disentangling serial number collisions.
#'  \item "bootnum":  boot count (integer)
#'  \item "ts":  timestamp embedded in name (double, with class \code{c("POSIXt", "POSIXct")} )
#'  \item "tsCode":  timestamp code ('P' means before GPS fix, 'Z' means accurate to 1e-6 s, 'Y' to 1e-5s, 'X' to 1e-4s, ..., 'T' to 1s)
#'  \item "port":  port number, if this file is associated with a single port (e.g. a .WAV file); NA if all ports
#'  \item "extension":  extension of uncompressed file; e.g. ".txt"
#'  \item "comp":  integer; file compression type":  NA = uncompressed, 1 = gzip, 2 = lzip
#'
#' }
#' @note Returns NULL if no filenames match regex; otherwise, return value has rows
#' filled with NA for any filenames not matching regex.
#'
#' @note To resolve the collision between the CTRiver/Sugarloaf and Motus/PointLepreau receivers which
#' both have serial number 1614BBBK1911, we give Sugarloaf an additional "_1".  This change is also
#' effected by renaming the files on disk.
#' 
#' 
#' @export

parseFilenames = function(f) {
    rv = splitToDF(sgFilenameRegex, f, as.is=TRUE, validOnly=FALSE)
    if (is.null(rv))
        return(rv)
    rv$ts = ymd_hms(rv$ts)
    fix = which(rv$serno == "1614BBBK1911" & rv$prefix != "Lepreau")
    if (length(fix) > 0) {
        rv$serno[fix] = "1614BBBK1911_1"
        file.rename(f[fix], sub("1614BBBK1911", "1614BBBK1911_1", f[fix], fixed=TRUE))
    }
    return(rv)
}
