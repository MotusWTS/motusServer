#' parse sensorgnome filenames into components
#'
#' @param f character vector of filenames with full path
#'
#' @param base character vector of file basenames; these default to
#'     \code{basename(f)}, but will differ when the basename has been
#'     corrected (e.g. to remove invalid UTF-8 sequences).
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
#' @note Sometimes filenames arrive with shortened, DOS-style (8.3 character)  names.  This function will handle
#' such files like so:
#'
#' \itemize{
#'
#' \item if there are files with unaltered long names from exactly one
#' sensorgnome in \code{f}, then the shortened files are assumed to
#' have come from that receiver, and their names are corrected
#' post-hoc using content timestamps (see
#' \link{\code{fixDOSfilenames}}).
#'
#' \item otherwise, we can't tell which receiver(s) the misnamed files
#' belong to, so they are saved in a subfolder of "/sgm/manual" with a
#' "README.TXT" giving details.
#'
#' }
#'
#'
#' @export

parseFilenames = function(f, base=basename(f)) {
    rv = splitToDF(sgFilenameRegex, base, as.is=TRUE, validOnly=FALSE)
    if (is.null(rv))
        return(rv)

    ## check for 8.3 DOS filenames, which are shortened SG filenames
    dos = grepl(MOTUS_DOS_FILENAME_REGEX, base, perl=TRUE)

    if (any(dos)) {
        if (length(unique(rv$serno)) == 1) {
            f[dos] = fixDOSfilenames(f, dos)
            base[dos] = basename(f[dos])  ##
        } else {
            ## oops - can't tell what receiver these are from.
            motusLog("Can't determine receiver for files with short names: %s",
                     paste(base[dos], collapse="\n   "))
            embroilHuman(f[dos], "Annoying files with shortened names!")
            f = f[! dos]
            basename = basename[! dos]
        }
    }

    rv$ts = ymd_hms(rv$ts)
    ## fix only known (as of Sept. 2016) serial number collision

    fix = which(rv$serno == "1614BBBK1911" & rv$prefix != "Lepreau")
    if (length(fix) > 0) {
        rv$serno[fix] = "1614BBBK1911_1"
        file.rename(f[fix], sub("1614BBBK1911", "1614BBBK1911_1", f[fix], fixed=TRUE))
    }
    return(rv)
}
