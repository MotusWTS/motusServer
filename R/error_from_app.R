#' return an error from a Rook app
#'
#' This function is called to generate an in-band error reply to the API
#' request.  The remote requestor will still receive a bzip2-compressed
#' JSON-formatted object, but that object will have a single field
#' named "error", whose value is the string passed to this function.
#'
#' Objects returned from successful API calls \emph{never} include a
#' top-level field called "error".
#'
#' @param error character scalar error message to return to app caller
#'
#' @return Similar to the return value from
#'     \link{\code{return_from_app}}, except blessed with class
#'     "error", to make it easy for rook apps to check for an error;
#'     e.g. \code{if (inherits(X, "error")) return(X)}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

error_from_app = function(error) {
    return_from_app(list(error=error))
}
