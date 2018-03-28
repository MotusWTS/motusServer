#' return the contens of a file from a Rook app
#'
#' This returns a file using the user-specified type.  File contents
#' are not modified.
#'
#' @param file path to the file
#'
#' @param name name by which the file should be called on client's side
#'
#' @param type content type; default: "text/plain; charset=utf-8"
#'
#' @param encoding content encoding; only emitted if non-NULL; default: NULL
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

return_file_from_app = function(file, name=basename(file), type="text/plain; charset=utf-8", encoding=NULL) {
    res = Rook::Response$new()
    res$header("Cache-control", "no-cache")
    res$header("Content-Type", type)
    if (!is.null(encoding))
        res$header("Content-Encoding", encoding)
    res$header("Content-Disposition", paste0('attachment; filename="', name, '"'))
    res$body = readBin(file, raw(), n=file.size(file))
    res$finish()
}
