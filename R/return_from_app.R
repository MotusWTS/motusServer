#' return an object from a Rook app
#'
#' This includes generating headers, bzip2-compressing the object payload, and
#' returning the response.  Even app errors are returned by this function,
#' through a call to \link{\code{error_from_app}}
#'
#' @param rv the object to return.
#'
#' @return the return value suitable as a return value for a Rook app.
#'     This is the result of calling \code{Rook::Response}'s
#'     \code{finish()} method.
#'
#' @note This function is called to return a value by all API entries
#'     supported by this package.  These are implemented as Rook apps
#'     as part of \link{\code{dataServer}} or
#'     \link{\code{statusServer}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

return_from_app = function(rv) {
    res = Rook::Response$new()
    res$header("Cache-control", "no-cache")
    res$header("Content-type", "application/json")
    res$header("Content-Encoding", "bzip2")
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "bzip2")
    res$finish()
}
