#' parse sensorgnome filenames into components
#'
#' @param f character vector of filenames with full path
#'
#' @param base character vector of file basenames; these default to
#'     \code{basename(f)}, but will differ when the basename has been
#'     corrected (e.g. to remove invalid UTF-8 sequences).
#'
#' @param checkDOS if TRUE, the default, try to correct DOS 8.3-style filenames;
#' if FALSE, return NA for rows corresponding to these.
#'
#' @return a dataframe of components, with one row per filename and these columns:
#'
#' \enumerate{
#'  \item prefix:  human readable short site name
#'  \item serno:  receiver serial number; "SG-" followed by 12 alphanumeric characters e.g. 1315BBBK2156, or possibly with an appended "_N" where N is 1, 2, ...
#'  for disentangling serial number collisions.  Alphabetic characters are converted to upper case.
#'  \item bootnum:  boot count (integer)
#'  \item tsString: timestamp in YYYY-MM-DDTHH-MM-SS.SSSS format
#'  \item ts:  timestamp embedded in name (double, with class \code{c("POSIXt", "POSIXct")} )
#'  \item tsCode:  timestamp code ('P' means before GPS fix, 'Z' means accurate to 1e-6 s, 'Y' to 1e-5s, 'X' to 1e-4s, ..., 'T' to 1s)
#'  \item port:  character; port label, if this file is associated with a single port (e.g. a .WAV file); "all" if all ports
#'  \item extension:  character extension of uncompressed file; e.g. ".txt"; lower case
#'  \item comp:  character; file compression type, if any:  "", or ".gz"; lower case
#' }
#' @note:
#' \itemize{
#' \item returns NULL if no filenames match regex; otherwise, return value has rows
#' filled with NA for any filenames not matching the expected form
#'
#' \item serial number collisions are resolved based on prefix and possibly other
#' filename components - see the
#' variable \code{sernoCollisionFixes}.  Resolution occurs by adding a suffix to the \code{serno}
#' field returned by this function, but does not rename files.
#' }
#' @export

parseFilenames = function(f, base=basename(f), checkDOS=TRUE) {
    rv = splitToDF(sgFilenameRegex, base, guess=FALSE, validOnly=FALSE)
    if (is.null(rv))
        return(rv)

    ## add the "SG-" prefix; everywhere else in this package, serial numbers of SGs start with "SG-".
    ## make an exception for CTT serial numbers (those already have the CTT prefix included).

    rv$serno = ifelse(is.na(rv$serno), NA, ifelse(any(toupper(substring(rv$serno, 1, 4)) == c("CTT-", "SEI_")), toupper(rv$serno), paste0("SG-", rv$serno)))

    ## check and correct 8.3 DOS filenames, which are shortened SG filenames

    rv$bootnum = as.integer(rv$bootnum)
    rv$ts = ymd_hms(rv$tsString)

    if (checkDOS)
        rv = fixDOSfilenames(f, rv)

    ## fix serial number collisions according to rules.  Once a filename has been matched by a rule,

    rules = MetaDB("select * from serno_collision_rules where serno in (%s) order by id", paste0("'", rv$serno, "'", collapse=","), .QUOTE=FALSE)

    ## keep track of the filenames for which we've corrected serno.  We only correct once.
    unfixed = rep(TRUE, nrow(rv))
    for (i in seq_len(nrow(rules))) {
        fix = with(rv, which(unfixed & serno == rules$serno[i] & eval(parse(text=rules$cond[i]))))
        if (length(fix)) {
            rv$serno[fix] = paste0(rv$serno[fix], rules$suffix[i])
            unfixed[fix] = FALSE
        }
    }

    ## Thanks to read.csv semantics in splitToDF, if none of the files
    ## was a .gz, then column the 'comp' column is logical NA,
    ## but if any of the files was a .gz, those which weren't have
    ## comp=""; so make the column "" in the former case.

    if (is.logical(rv$comp))
        rv$comp = ""

    return(rv)
}
