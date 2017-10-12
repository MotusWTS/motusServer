#' validate an API request by looking up its token
#'
#' @param json named list with at least these items:
#' \itemize{
#' \item authToken authorization token
#' \item projectID (optional) projectID
#' }
#'
#' @param needProjectID logical; if TRUE, a projectID to which the user
#' has permission must be in \code{json}; default:  TRUE
#'
#' @param needAdmin logical; if TRUE, the user must have userType="administrator"
#' in order to use the entry point; default:  FALSE
#'
#' @return  If the request was valid, a list with these items:
#' \itemize{
#' \item userID integer user ID
#' \item projects integer vector of *all* project IDs user has permission to
#' \item projectID the projectID specified in the request (and it is guaranteed the user has permission to this project)
#' }
#'
#' If the request was not valid, a value of class "error" and suitable
#' for return by a Rook app, which contains an appropriate error
#' message.  This value should be immediately returned by the caller.
#'
#' So typical usage is like:
#' \code{
#'    auth = validate_request(json, needProjectID=FALSE)
#'    if (inherits(auth, "error")) return(auth)
#'    projectID = auth$projectID
#' }
#'
#'
#' @note this function is meant for use inside Rook servers, such as \link{\code{dataServer}}
#' and \link{\code{statusServer}} in this package.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

validate_request = function(json, needProjectID=TRUE, needAdmin=FALSE) {

    msg = NULL

    openMotusDB() ## ensure connection is still valid after a possibly long time between requests

    authToken = (json$authToken %>% as.character)[1]
    projectID = (json$projectID %>% as.integer)[1]
    now = as.numeric(Sys.time())
    auth = AuthDB("
select
   userID,
   projects,
   expiry,
   userType
from
   auth
where
   token=:token",
token = authToken)
    if (! isTRUE(nrow(auth) > 0)) {
        ## authToken invalid
        msg = "token invalid"
    } else if (all(auth$expiry < now)) {
        ## authToken expired
        msg = "token expired"
    } else  {
        rv = list(userID=auth$userID, projects = scan(text=auth$projects, sep=",", quiet=TRUE), projectID=projectID)
        if (needProjectID && ! isTRUE(length(projectID) == 1 && projectID %in% rv$projects)) {
            ## user not authorized for project
            msg = "not authorized for project"
        }
        if (needAdmin && ! isTRUE(auth$userType == "administrator")) {
            ## user not authorized for call
            msg = "not authorized for this API call"
        }
    }
    if (! is.null(msg)) {
        return(error_from_app(msg))
    }
    return(rv)
}
