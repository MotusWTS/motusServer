#' running count of occurences for each unique value in a vector
#'
#' @details For an integer vector, returns a vector of equal length giving the
#'     number of times the i'th element occurs in the first i slots.
#'
#' @param x: integer vector
#'
#' @return integer vector \code{rv}; \code{rv[i] =
#'     sum(x[1:i] == x[i])}
#'
#' @note: despite the O(log(length(x))) call to \code{order()},
#'     this works faster up to at least length(x) == 1E8 than a similar
#'     version that first converts to a factor and then orders using
#'     method="radix"
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'
#' @examples
#'
#' runID = ceiling(10 * runif(100))
#' posInRun = runningCount(runID)
#' for (i in seq(along=runID)) if (posInRun[i] != sum(runID[1:i] == runID[i])) stop("runningCount failed!")

runningCount = function(x) {
    n = length(x)
    ## create the running count vector in the sorted domain
    i = order(x)
    jump = c(FALSE, diff(x[i]) != 0)
    j = cumsum(rep(1L, n)) - cummax(jump * (seq(from=0, length=n)))
    rv = integer(n)
    ## map the count back to the original domain
    rv[i] = j
    return(rv)
}
