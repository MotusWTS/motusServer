#' serve http requests for tag detection data
#'
#' @param port integer; local port on which to listen for requests
#' Default: 0xda7a
#'
#' @param tracing logical; if TRUE, run interactively, allowing local user
#' to enter commands.
#'
#' @return does not return; meant to be run as a server.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

dataServer = function(port=0xda7a, tracing=FALSE) {

    library(Rook)
    library(hwriter)
    library(RCurl)
    library(jsonlite)

    ## open the "motus transfer" database, putting a safeSQL object in the global MotusDB
    openMotusDB()

    ## options for this server:

    ## lifetime of authorization token: 3 days
    OPT_AUTH_LIFE <<- 3 * 24 * 3600

    ## number of random bits in authorization token;
    ## gets rounded up to nearest multiple of 8
    OPT_TOKEN_BITS <<- 33 * 8

    tracing <<- tracing

    ## save server in a global variable in case we are tracing

    SERVER <<- Rhttpd$new()

    CURL <<- getCurlHandle()

    ## get user auth database

    AUTHDB <<- safeSQL(file.path(MOTUS_PATH$USERAUTH, "data_user_auth.sqlite"))
    AUTHDB("create table if not exists auth (token TEXT UNIQUE PRIMARY KEY, expiry REAL, userID INTEGER, projects TEXT, receivers TEXT)")
    AUTHDB("create index if not exists auth_expiry on auth (expiry)")
    AUTHDB("create unique index if not exists auth_userID on auth (userID)")

    ## add each function below as an app

    for (f in allDataApps)
        SERVER$add(RhttpdApp$new(app = get(f), name = f))

    motusLog("Data server started")

    SERVER$start(port = port)

    if (! tracing) {
        ## sleep while awaiting requests
        suspend_console()
    }
}

## a string giving the list of apps for this server

allDataApps = c("authenticate_user", "batches_for_tag_project")

#' authenticate_user return a list of projects and receivers the user is authorized to receive data for
#'
#' This is an app used by the Rook server launched by \code{\link{dataServer}}
#' Params are passed as a url-encoded field named 'json' in the http GET request.
#' The return value is a JSON-formatted string
#'
#' @param user motus user name
#' @param password motus password (plaintext)
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
#'

authenticate_user = function(env) {

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json <- req$GET()[['json']] %>% fromJSON()
    username <- json$user
    password <- json$password

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "application/json")

    motusReq = toJSON(list(
        date = format(Sys.time(), "%Y%m%d%H%M%S"),
        login = username,
        pword = password,
        type = "csv"),
        auto_unbox = TRUE)

    rv = NULL
    tryCatch({
        resp = getForm(motusServer:::MOTUS_API_USER_VALIDATE, json=motusReq, curl=CURL) %>% fromJSON
        ## generate a new authentication token for this user
        rv = list(
            token = unclass(RCurl::base64(readBin("/dev/urandom", raw(), n=ceiling(OPT_TOKEN_BITS / 8)))),
            expiry = as.numeric(Sys.time()) + OPT_AUTH_LIFE,
            userID = resp$userID,
            projects = resp$projects,
            receivers = NULL
        )

        ## add the auth info to the database for lookup by token
        AUTHDB("replace into auth (token, expiry, userID, projects) values (:token, :expiry, :userID, :projects)",
               token = rv$token,
               expiry = rv$expiry,
               userID = rv$userID,
               projects = rv$projects %>% toJSON (auto_unbox=TRUE) %>% unclass
               )
    },
    error = function(e) {
        rv <<- list(error="authentication with motus failed")
    })

    res$write(toJSON(rv, auto_unbox=TRUE))
    res$finish()
}

#' validate a request by looking up its token, failing gracefully
#' @param authToken authorization token
#' @param projectID (optional)
#'
#' @return if \code{authToken} represents a valid unexpired token, and projectID is
#' a project for which the user is authorized, returns
#' a list with these items:
#' \itemize{
#' \item userID integer user ID
#' }
#' Otherwise, send a JSON-formatted reply with the single item "error": "authorization failed"
#' and call stop(), which ends processing of the current request.

validate_request = function(req, res) {
    authToken = req$GET()[["authToken"]]
    projectID = req$GET()[["projectID"]] %>% as.integer
    now = as.numeric(Sys.time())
    rv = AUTHDB("select userID, (select group_concat(key, ',') from json_each(projects)) as projects from auth where token=:token and expiry > :now",
                token = authToken,
                now = now)
    okay = TRUE
    if (! isTRUE(nrow(rv) > 0)) {
        ## authToken invalid or expired
        okay = FALSE
    } else  {
        rv = list(userID=rv$userID, projects = scan(text=rv$projects, sep=","))
        if (!isTRUE(is.null(projectID) || isTRUE(projectID %in% rv$projects))) {
            ## user not authorized for project
            okay = FALSE
        }
    }
    if (! okay) {
        res$write(toJSON(list(error="authorization failed"), auto_unbox=TRUE))
        res$finish()
        stop("authorization failure; token=", authToken, "projectID=", if (is.null(projectID)) "null" else projectID)
    }
    return(rv)
}

#' get batches for a tag project
#'
#' @param projectID integer project ID
#' @param ts numeric timestamp
#'
#' @return

batches_for_tag_project = function(env) {

    MAX_BATCHES_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    projectID = req$GET()[['projectID']] %>% as.integer
    auth = validate_auth(req, res, projectID)

    ts = req$GET()[['ts']] %>% as.real

    meta = safeSQL(getMotusMetaDB())

    projTags = meta("select distinct tagID from tags where projectID = :projectID", projectID=projectID)
    dbCreateTable(environment(MotusDB)$con, "create temporary table tempProjectTagIDs (tagID integer unique primary key)")
    dbWriteTable(environment(MotusDB)$con, "tempProjectTagIDs", projTags, row.names=FALSE)
    rv = MotusDB("select batchID from batches as t1 join runs as t2 on t1.batchID=t2.batchIDbegin join tempProjectTagIDs as t3 on t2.motusTagID=t3.tagID where t1.tsSG>%f", ts)
    res$write(toJSON(rv, auto_unbox=TRUE))
    res$finish()
}
