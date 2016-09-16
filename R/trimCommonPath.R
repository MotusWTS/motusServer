#' Remove any common leading path from a set of paths.
#'
#' @param files character vector of full paths to files
#'
#' @return \code{files}, with any leading common path removed.
#'
#' @examples trimCommonPath(c("/A/B/C", "/A/B/D/E", "/A/B/F")) == c("C", "D/E", "F")
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

trimCommonPath = function(files) {

    ## remove leading slashes and split into path components

    parts = strsplit(sub("^/+", "", files, perl=TRUE),
                    .Platform$file.sep, fixed=TRUE)

    ## longest possible number of common path components, not counting
    ## final one

    n = min(sapply(parts, length)) - 1

    if (n == 0)
        return(files)

    ith     = function(x, i) sapply(x, `[`,  i)
    fromIth = function(x, i) lapply(x, `[`, - (1:i))

    i = 1
    while(i < n && length(unique(ith(parts, i))) == 1) {
        i = i + 1
    }

    sapply(fromIth(parts, i), paste, collapse=.Platform$file.sep, USE.NAMES=FALSE)
}
