#' bless a numeric vector with "timestamp" class
#'
#' adds \code{c("POSIXt", "POSIXct")} to the beginning of the class
#' attribute of a numeric vector so that operations such as arithmetic
#' and printing treat it as a timestamp.
#'
#' @param x numeric vector; should be seconds since the unix epoch (1 Jan 1970 GMT).
#'
#' @return structure(x, class=c("POSIXt", "POSIXct", class(x)))
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

TS = function(x) {
    if (! is.numeric(x))
        stop("must be numeric")
    structure(x, class=c("POSIXt", "POSIXct", class(x)))
}
