#' return an object from a Rook app
#'
#' This includes generating headers, bzip2-compressing the object payload, and
#' returning the response.  Even app errors are returned by this function,
#' through a call to \link{\code{error_from_app}}.  If the env() variable
#' in the parent frame contains a value called `HTTP_ACCEPT_ENCODING` and
#' that value includes the string "gzip", then as a special case, this
#' function returns its data gzip-compressed with header `Content-Encoding: gzip`.
#' This is to support directly calling this API from client-side javascript, which
#' in Firefox, at least, doesn't support bzip2-compression.
#'
#' @param rv the object to return.
#'
#' @param isJSON logical; is `rv` already JSON?  If so, serialization
#' of `rv` to JSON is skipped.  Default: FALSE
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

return_from_app = function(rv, isJSON=FALSE) {
    n = 1
    ## ascend up to 10 frames to find an environment called `env`
    while (n < 10) {
        env = parent.frame(n)$env
        if (! is.null(env) && is.environment(env))
            break
        n = n + 1
    }
    if (isTRUE(grepl("gzip", env$HTTP_ACCEPT_ENCODING)))
        compress = "gzip"
    else
        compress = "bzip2"
    res = Rook::Response$new()
    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "application/json")
    res$header("Content-Encoding", compress)
    if (isJSON) {
        payload = rv
    } else {
        payload = unclass(toJSON(rv, auto_unbox=TRUE, dataframe="columns"))
    }
    if (compress == "gzip") {
        ## sigh: another R edge case: memCompress (, type="gzip") doesn't include headers
        ## so we use gzcon() instead
        gzf = tempfile()
        gzbody = gzfile(gzf, "wb")
        writeChar(payload, gzbody, eos=NULL)
        close(gzbody)
        res$body = readBin(gzf, raw(0), n=file.info(gzf)$size)
        file.remove(gzf)
    } else {
        res$body = memCompress(payload, compress)
    }
    res$finish()
}
