#' Extract named items from strings according to a regular expression.
#'
#' FIXME (eventually): when the stringi package regex code can handle
#' named subexpressions, use \code{stri_extract_all_regex(...,
#' simplify=TRUE)}
#'
#' @param rx Perl-type regular expression with named fields, as
#'     described in \code{?regex}
#'
#' @param s character vector.
#'
#' @return a list of character vectors.  Each vector corresponds to an
#'     item of \code{s}.  The vector items are substrings of the input
#'     item corresponding to named capture groups in \code{rx}, in the
#'     order they appear in the input item.  The vector names are
#'     those of the capture group.  The same name might appear more
#'     than once in the vector.  If an item in the input does not
#'     match any capture of \code{rx}, then its corresponding vector
#'     in the output is empty.
#'
#' @examples
#'
#' rx = "(?<ayes>a+)|(?<bees>b+)|(?<sees>c+)"
#' s = c("anybbody", "something", "aebbfcbggaa")
#' regexPieces(rx, s)
#' ## returns:
#' ##  [[1]]
#' ##  ayes bees
#' ##   "a" "bb"
#' ##
#' ##  [[2]]
#' ##  named character(0)
#' ##
#' ##  [[3]]
#' ##  ayes bees sees bees ayes
#' ##   "a" "bb"  "c"  "b" "aa"
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#' @export

regexPieces = function(rx, s) {
    v = gregexpr(rx, s, perl=TRUE)

    lapply(seq(along=s),
           function(i) {
               ## transpose to extract in order of appearance,
               ## rather than in order by capture group
               a = t(attr(v[[i]], "capture.start"))
               b = t(attr(v[[i]], "capture.length"))
               nz = b > 0
               structure(
                   stri_sub(
                       s[i],
                       from   = a[nz],
                       length = b[nz]
                   ),
                   names = rownames(b)[row(b)[nz]]
               )
           }
           )
}
