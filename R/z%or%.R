#' perl/javascript style "or"
#'
#' returns the first argument, if FALSE or of length 0; otherwise
#' the second.
#'
#' @param x first argument, of any class
#'
#' @param y second argument, of any class
#'
#' @return \code{x}, unless x is either the logical scalar FALSE, or has
#' length 0, in which case return \code{y}.  Note that length(NULL) is 0.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

`%or%` = function(x, y) {
    if (length(x) == 0 || (is.logical(x) && length(x) == 1 && !x))
        y
    else
        x
}
