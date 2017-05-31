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

    ## assign global MotusCon to be the low-level connection behind MotusDB, as some
    ## functions must us that

    MotusCon <<- MotusDB$con

    ## assign global MetaDB to be a safeSQL connection to the cached motus metadatabase
    MetaDB <<- safeSQL(getMotusMetaDB())

    ## options for this server:

    ## lifetime of authorization token: 3 days
    OPT_AUTH_LIFE <<- 3 * 24 * 3600

    ## number of random bits in authorization token;
    ## gets rounded up to nearest multiple of 8
    OPT_TOKEN_BITS <<- 33 * 8

    tracing <<- tracing

    ## save server in a global variable in case we are tracing
    ## (weird assignment is because "Server" is already bound in Rook package,
    ## which is on our search path)

    .GlobalEnv$Server = Rhttpd$new()

    Curl <<- getCurlHandle()

    ## get user auth database

    AuthDB <<- safeSQL(file.path(MOTUS_PATH$USERAUTH, "data_user_auth.sqlite"))
    AuthDB("create table if not exists auth (token TEXT UNIQUE PRIMARY KEY, expiry REAL, userID INTEGER, projects TEXT, receivers TEXT)")
    AuthDB("create index if not exists auth_expiry on auth (expiry)")
    AuthDB("create unique index if not exists auth_userID on auth (userID)")

    ## add each function below as an app

    for (f in allDataApps)
        Server$add(RhttpdApp$new(app = get(f), name = f))

    motusLog("Data server started")

    Server$start(port = port)

    if (! tracing) {
        ## sleep while awaiting requests
        suspend_console()
    }
}

## a string giving the list of apps for this server

allDataApps = c("authenticate_user", "batches_for_tag_project", "batches_for_receiver_project", "runs_for_tag_project")

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

    sendHeader(res)

    motusReq = toJSON(list(
        date = format(Sys.time(), "%Y%m%d%H%M%S"),
        login = username,
        pword = password,
        type = "csv"),
        auto_unbox = TRUE)

    rv = NULL
    tryCatch({
        resp = getForm(motusServer:::MOTUS_API_USER_VALIDATE, json=motusReq, curl=Curl) %>% fromJSON
        ## generate a new authentication token for this user
        rv = list(
            token = unclass(RCurl::base64(readBin("/dev/urandom", raw(), n=ceiling(OPT_TOKEN_BITS / 8)))),
            expiry = as.numeric(Sys.time()) + OPT_AUTH_LIFE,
            userID = resp$userID,
            projects = resp$projects,
            receivers = NULL
        )

        ## add the auth info to the database for lookup by token
        AuthDB("replace into auth (token, expiry, userID, projects) values (:token, :expiry, :userID, :projects)",
               token = rv$token,
               expiry = rv$expiry,
               userID = rv$userID,
               projects = rv$projects %>% toJSON (auto_unbox=TRUE) %>% unclass
               )
    },
    error = function(e) {
        rv <<- list(error="authentication with motus failed")
    })

    res$body = memCompress(toJSON(rv, auto_unbox=TRUE), "gzip")
    res$finish()
}

#' validate a request by looking up its token, failing gracefully
#' @param json named list with at least these items:
#' \itemize{
#' \item authToken authorization token
#' \item projectID (optional) projectID
#' }
#'
#' @return if \code{authToken} represents a valid unexpired token, and projectID is
#' a project for which the user is authorized, returns
#' a list with these items:
#' \itemize{
#' \item userID integer user ID
#' }
#' Otherwise, send a JSON-formatted reply with the single item "error": "authorization failed"
#' and return NULL.

validate_request = function(json, res) {

    authToken = json$authToken
    projectID = json$projectID
    now = as.numeric(Sys.time())
    rv = AuthDB("select userID, (select group_concat(key, ',') from json_each(projects)) as projects from auth where token=:token and expiry > :now",
                token = authToken,
                now = now)
    okay = TRUE
    if (! isTRUE(nrow(rv) > 0)) {
        ## authToken invalid or expired
        okay = FALSE
    } else  {
        rv = list(userID=rv$userID, projects = scan(text=rv$projects, sep=",", quiet=TRUE))
        if (length(projectID) > 0 && ! isTRUE(projectID %in% rv$projects)) {
            ## user not authorized for project
            okay = FALSE
        }
    }
    if (! okay) {
        sendHeader(res)
        sendError(res, "authorization failed")
        rv = NULL
    }
    return(rv)
}

#' send the header for a reply
#' @param res Rook::Response object
#' @return no return value
#'
#' @details the reply will always be a gzip-compressed JSON-encoded value.
#' We also disable caching.
#'
sendHeader = function(res) {
    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "application/json")
    res$header("Content-Encoding", "gzip")
}

#' send an error as the reply
#' @param res Rook::Response object
#' @param error character vector with error message(s)
#' @return no return value
#'
#' @details

sendError = function(res, error) {
    res$body = memCompress(toJSON(list(error=error), auto_unbox=TRUE), "gzip")
}


#' get batches for a tag project
#'
#' @param projectID integer project ID
#' @param ts numeric timestamp
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_tag_project = function(env) {

    MAX_BATCHES_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$GET()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID
    ts = json$ts %>% as.numeric
    if (!isTRUE(is.finite(ts)))
        ts = 0

    projTags = MetaDB("select distinct tagID from tags where projectID = :projectID", projectID=projectID)
    tmpTab = paste0("tempTagIDs", projectID)
    MotusDB(paste0("create temporary table if not exists ", tmpTab, " (tagID integer unique primary key)"))
    MotusDB(paste0("delete from ", tmpTab))
    dbWriteTable(MotusCon, tmpTab, projTags, row.names=FALSE, append=TRUE)
    query = sprintf("\
select t3.batchID, t3.motusDeviceID, t3.monoBN, t3.tsBegin, t3.tsEnd, t3.numHits, t3.ts \
  from %s as t1 join runs as t2 on t1.tagID=t2.motusTagID join batches as t3 on t2.batchIDbegin=t3.batchID \
  where t3.ts > %f group by t3.batchID order by t3.batchID limit %d",
tmpTab, ts, MAX_BATCHES_PER_REQUEST)

    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get batches for a receiver project
#'
#' @param projectID integer project ID
#' @param ts numeric timestamp
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_receiver_project = function(env) {

    MAX_BATCHES_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$GET()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID
    ts = json$ts %>% as.numeric
    if (!isTRUE(is.finite(ts)))
        ts = 0

    ## get a table of receiver deployments for this project

    ## If a deployment has no tsEnd specified, we look for the start
    ## of the next chronological deployment, and use that (minus 1
    ## second).  This prevents users from obtaining data for later
    ## deployments of their receivers by other projects by simply
    ## specifying no tsEnd for their own deployment.

    recvDeps = MetaDB("select deviceID, tsStart, ifnull(tsEnd, (select max(t1.tsStart)-1 from recvDeps as t1 where t1.deviceID=deviceID and t1.tsStart > tsStart)) as tsEnd from recvDeps where projectID=:projectID", projectID=projectID)
    tmpTab = paste0("tempRecvDeps", projectID)
    MotusDB(paste0("create temporary table if not exists ", tmpTab, " (deviceID integer, tsStart float(53), tsEnd float(53))"))
    MotusDB(paste0("delete from ", tmpTab))
    dbWriteTable(MotusCon, tmpTab, recvDeps, row.names=FALSE, append=TRUE)

    ## pull out appropriate batches

    query = sprintf("\
select t2.batchID, t2.motusDeviceID, t2.monoBN, t2.tsBegin, t2.tsEnd, t2.numHits, t2.ts from %s as t1 \
       join batches as t2 on t1.deviceID=t2.motusDeviceID where t2.ts > %f \
       and ((t1.tsEnd is null and t2.tsBegin >= t1.tsStart)
            or not (t2.tsEnd <= t1.tsStart or t2.tsBegin >= t1.tsEnd)) limit %d",
tmpTab, ts, MAX_BATCHES_PER_REQUEST)
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get runs by tag project from a batch
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param runID integer ID of largest run already obtained
#'
#' @return a data frame with the same schema as the runs table, but JSON-encoded as a list of columns

runs_for_tag_project = function(env) {

    MAX_BATCHES_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$GET()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    runID = json$runID %>% as.integer

    if (!isTRUE(is.finite(projectID) && is.finite(batchID) && is.finite(runID))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    # regenerate a list of tag IDs for this project
    projTags = MetaDB("select distinct tagID from tags where projectID = :projectID", projectID=projectID)
    tmpTab = paste0("tempTagIDs", projectID)
    MotusDB(paste0("create temporary table if not exists ", tmpTab, " (tagID integer unique primary key)"))
    MotusDB(paste0("delete from ", tmpTab))
    dbWriteTable(MotusCon, tmpTab, projTags, row.names=FALSE, append=TRUE)

    ## pull out appropriate runs

    query = sprintf("\
select t2.runID, t2.batchIDbegin, t2.batchIDend, t2.motusTagID, t2.ant, t2.len from batches as t1 \
       join runs as t2 on t2.batchIDbegin=t1.batchID join %s as t3 on t2.motusTagID=t3.tagID where \
       t1.batchID = %d and t2.runID > %d limit %d",
tmpTab, batchID, runID, MAX_BATCHES_PER_REQUEST)
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}
