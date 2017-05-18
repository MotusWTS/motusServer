#' reply to http requests for information on the processing queue
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

    library(motusServer)  ## FIXME: remove this once being used from within the motusServer package

    library(Rook)
    library(hwriter)
    library(RCurl)
    library(jsonlite)

    openMotusDB()

    ## options for this server:

    ## lifetime of authorization token: 3 days
    OPT_AUTH_LIFE <<- 3 * 24 * 3600

    ## number of random bits in authorization token
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

    for (f in allApps)
        SERVER$add(RhttpdApp$new(app = get(f), name = f))

    motusLog("Data server started")

    SERVER$start(port = port)

    if (! tracing) {
        ## sleep while awaiting requests
        suspend_console()
    }
}

## a string giving the list of apps for this server

allApps = c("authenticate_user")

#' authenticate_user return a list of projects and receivers the user is authorized to receive data for
authenticate_user = function(env) {

    ## return summary table of latest top jobs, with clickable expansion for details
    ## parameters:
    ##   - U: username
    ##   - P: plaintext password

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json <- req$GET()[['json']] %>% fromJSON()
    username <- json$U
    password <- json$P

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "application/json")

    motusReq = toJSON(list(
        date = format(Sys.time(), "%Y%m%d%H%M%S"),
        login = username,
        pword = password,
        type = "csv"),
        auto_unbox = TRUE)

    resp = getForm(motusServer:::MOTUS_API_USER_VALIDATE, json=motusReq, curl=CURL) %>% fromJSON
    if (!isTRUE(is.finite(resp$userID))) {
        rv = list(error="authentication failed")
    } else {
        ## generate a new authentication token for this user
        rv = list(
            token = unclass(RCurl::base64(readBin("/dev/urandom", raw(), n=ceiling(OPT_TOKEN_BITS / 8)))),
            expiry = as.numeric(Sys.time()) + OPT_AUTH_LIFE,
            userID = resp$userID,
            projects = resp$projects,
            receivers = NULL
        )  ## FIXME

        AUTHDB("replace into auth (token, expiry, userID, projects) values (:token, :expiry, :userID, :projects)",
               token = rv$token,
               expiry = rv$expiry,
               userID = rv$userID,
               projects = rv$projects %>% toJSON %>% unclass)
    }
    res$write(toJSON(rv, auto_unbox=TRUE))
    res$finish()
}
