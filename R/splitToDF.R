#' Read a data.frame from a character vector according to a regular expression.
#'
#' Read a dataframe from a character vector, using a regular
#' expression with named fields to extract values from matching items.  The
#' named fields become columns in the result, and each matching item in the
#' input yields a row in the result.
#' FIXME (Eventually): when the stringi package regexp code can handle named
#' subexpressions, use stri_extract_all_regex(..., simplify=TRUE)
#'
#' @param rx: Perl-type regular expression with named fields, as
#'     described in \code{?regex}
#'
#' @param s: character vector.  Each element must match \code{rx},
#'     i.e.  must have at least one character matching each named
#'     field in \code{rx}.
#'
#' @param namedOnly: if \code{TRUE} (the default), return columns only
#'     for named subexpressions of the regex.  Otherwise, a column is
#'     returned for every subexpression.
#'
#' @param validOnly: if \code{TRUE} (the default), return rows only
#'     for elements of \code{s} matching \code{rx}.  Otherwise, a row
#'     is returned for each element of \code{s}, and rows for those
#'     not matching \code{rx} are filled with NA.
#'
#' @param guess: if \code{TRUE} paste the columns together with
#'     commas, and use read.csv to try return the columns already
#'     converted to appropriate types, e.g. integer or real. Defaults
#'     to \code{TRUE}.
#'
#' @param ...: additional parameters to \code{read.csv()} used when
#'     \code{guess} is \code{TRUE}.
#'
#' @return a data.frame.  Each column is a vector and corresponds to a
#'     named field in \code{rx}, going from left to right.  Each row in
#'     the data.frame corresponds to an item in \code{s} which matches \code{rx}.
#'     If no items of \code{s} match \code{rx}, the function
#'     returns \code{NULL}.  If \code{guess} is \code{TRUE}, columns
#'     have been converted to their guessed types.
#'
#' @note This function serves a similar purpose to \code{read.csv},
#'     except that the rules for splitting input lines into columns
#'     are much more flexible.  Any format which can be described by a
#'     regular expression with named fields can be handled.  For
#'     example, logfile messages often contain extra text and variable
#'     field positions and interspersed unrelated messages which
#'     prevent direct use of functions like \code{read.csv} or
#'     \code{scan} to extract what is really just a dataframe with
#'     syntactic sugar and interleaved junk.
#'
#' For example, if input lines look like this:
#' \preformatted{
#' s = c( "Mar 10 06:25:11 SG [62442.231077] pps-gpio: PPS @@ 1425968711.000018004: pre_age = 163, post_age = 1130",
#'        "Mar 10 06:25:11 SG [62442.23108] usb-debug: device 45 disconnected",
#'        "Mar 10 06:25:12 SG [62443.2311] pps-gpio: PPS @@ 1425968712.000011015: pre_age = 1055, post_age = 11655",
#'        "Mar 10 06:25:13 SG [62444.2] dbus[2872]: [system] Successfully activated service 'org.freedesktop.PackageKit'
#'        "Mar 10 06:25:13 SG [62444.23] pps-gpio: PPS @@ 1425968713.000011275: pre_age = 160, post_age = 12120" )
#' }
#'
#' and we wish to extract timestamps and pre_age and post_age from the pps-gpio messages as a
#' data.frame, we can use this regular expression:
#' \preformatted{
#' rx = "pps-gpio: PPS @@ (?<ts>[0-9]+\\\\.[0-9]*): pre_age = (?<preAge>[0-9]+), post_age = (?<postAge>[0-9]+)"
#' }
#'
#' splitToDF(rx, s) then gives:
#' \preformatted{
#'           ts preAge postAge
#' 1 1425968711    163    1130
#' 2 1425968712   1055   11655
#' 3 1425968713    160   12120
#' }
#'
#' where the first column is numeric and others are integer.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#' @export

splitToDF = function(rx, s, namedOnly=TRUE, validOnly=TRUE, guess=TRUE, ...) {

    v = regexpr(rx, s, perl=TRUE)
    keepRow = which(attr(v, "match.length") > 0)

    ## non-trivial result
    if (length(keepRow) > 0 || ! validOnly) {
        ## get the names of captured fields
        nm = attr(v, "capture.names")

        ## drop unnamed fields if required

        keepCol = if (namedOnly) nm != "" else TRUE
        nm = nm[keepCol]

        ## allocate a return value list
        rv = vector("list", length(nm))

        ## get starting positions and lengths for each match in each item
        ## Note that rows correspond to named fields, columns to items of s.
        if (! validOnly)
            keepRow = seq_len(length(s))
        starts = attr(v, "capture.start")[keepRow, keepCol, drop=FALSE]
        lengths = attr(v, "capture.length")[keepRow, keepCol, drop=FALSE]

        ## for each field, extract the matched region of each item of s
        for (i in seq(along=nm))
            rv[[i]] = stri_sub(s[keepRow], from=starts[, i], length=lengths[, i])

        if (guess) {
            ## guess column types via read.csv()
            rv = read.csv(textConnection(do.call(paste, c(rv, sep=","))), header=FALSE, ...)
        } else {
            ## preserve columns as strings
            rv = as.data.frame(rv, stringsAsFactors=FALSE)
        }
        ## assign column names
        names(rv) = nm

        ## fill non-matching rows with NA
        if (!validOnly)
            rv[lengths < 0] = NA ## NB: lengths is a matrix with same shape as rv
    } else {
        rv = NULL
    }
    return (rv)
}
