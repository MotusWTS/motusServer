#' authenticate a user for a Rook request
#'
#' This is an app used by the Rook server launched by \code{\link{dataServer}}
#' Params are passed as a url-encoded field named 'json' in the http POST request.
#' The return value is a JSON-formatted string
#'
#' @param env Rook request environment
#'
#' @return a JSON list with these items:
#' \itemize{
#' \item token character scalar token used in subsequent API calls
#' \item expiry numeric timestamp at which \code{token} expires
#' \item userID integer user ID of user at motus
#' \item projects list of projects user has access to; indexed by integer projectID, values are project names
#' \item receivers FIXME: will be list of receivers user has access to
#' }
#' if the user is authorized.  Otherwise, return a JSON list with a single item
#' called "error".
#'
#' @note This is simply a convenience wrapper around \link{\code{motusAuthenticateUser}}

authenticate_user = function(env) {

    if (tracing)
        browser()

	motusLog("starting authenticate_user")
	
    rv = NULL

    tryCatch({
        json = parent.frame()$postBody["json"] ## Note: reaching into caller's frame to grab postBody
        json = fromJSON(json)  ## Note: don't combine this line with previous one - it will break.
    }, error = function(e) {
        rv <<- list(error="request is missing a json field or it has invalid JSON")
    })
    if (is.null(rv)) {
        username <- json$user
        password <- json$password

        tryCatch({
            rv = motusAuthenticateUser(username, password)
        },
        error = function(e) {
            rv <<- list(error=paste("authentication failed:", as.character(e)))
        })
    }
    return_from_app(rv)
}
