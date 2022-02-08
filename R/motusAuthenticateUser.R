#' authenticate a user with motus.org
#'
#' @param username motus user name
#' @param password motus password (plaintext)
#'
#' @return if the credentials are valid, a list with these items:
#' \itemize{
#' \item token character scalar token used in subsequent API calls
#' \item expiry numeric timestamp at which \code{token} expires
#' \item userID integer user ID of user at motus
#' \item projects list of projects user has access to; indexed by integer projectID, values are project names
#' \item receivers FIXME: will be list of receivers user has access to
#' }
#' Otherwise, generate an error.
#'
#' @note This function uses the global \code{AuthDB}, defined in \link{serverCommon}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusAuthenticateUser = function(username, password) {

    motusReq = toJSON(list(
        date = format(Sys.time(), "%Y%m%d%H%M%S"),
        login = username,
        pword = password,
        type = "csv"),
        auto_unbox = TRUE)

    tryCatch({
        resp = httr::content(httr::POST(motusServer:::MOTUS_API_USER_VALIDATE, body=list(json=motusReq),encode="form"))
    },
    error = function(e) {
        stop("query to main motus server failed")
    })
    if (isTRUE(resp$errorCode == "invalid-login"))
        stop("invalid credentials")

    ## generate a new authentication token for this user

    ## First, grab a list of ambiguous projects that this user
    ## gets access to by virtue of having access to real projects involved in them.

    realProjIDs = as.integer(names(resp$projects))
    projectIDs = c(realProjIDs)
    if(length(realProjIDs) > 0) {
        realProjIDString = paste(realProjIDs, collapse=",")
        ## ensure that the motus DB connection is valid; see issue #281
        openMotusDB()
        ambigProjIDs = MotusDB("
select
   distinct ambigProjectID
from
   projAmbig
where
   projectID1 in (%s)
   or projectID2 in (%s)
   or projectID3 in (%s)
   or projectID4 in (%s)
   or projectID5 in (%s)
   or projectID6 in (%s)
", realProjIDString, realProjIDString, realProjIDString, realProjIDString, realProjIDString, realProjIDString, .QUOTE=FALSE
)[[1]]
        projectIDs = c(projectIDs, ambigProjIDs)
    }
    rv = list(
        authToken = unclass(jsonlite::base64_enc(readBin("/dev/urandom", raw(), n=ceiling(MOTUS_TOKEN_BITS / 8)))),
        expiry = as.numeric(Sys.time()) + MOTUS_AUTH_LIFE,
        userID = resp$userID,
        projects = paste(projectIDs, collapse=","),
        receivers = NULL,
        userType = resp$userType
    )

    ## add the auth info to the database for lookup by token
    ## we're using replace into to cover the 0-probability case where token has been used before.
    AuthDB("replace into auth (token, expiry, userID, projects, userType) values (:token, :expiry, :userID, :projects, :userType)",
           token = rv$authToken,
           expiry = rv$expiry,
           userID = rv$userID,
           projects = rv$projects,
           userType = resp$userType
           )
    ## delete any expired tokens for user, while we're here.
    AuthDB("delete from auth where expiry < :now and userID = :userID",
           now = as.numeric(Sys.time()),
           userID = rv$userID)
    return(rv)
}
