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

    ## make sure the server database exists, is open, and put a safeSQL object in the global ServerDB
    ensureServerDB()

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

    ## start time for processing each request that passes through
    ## validate_request()

    ts_req <<- 0

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

allDataApps = c("authenticate_user",
                "deviceID_for_receiver",
                "receivers_for_project",
                "batches_for_tag_project",
                "batches_for_receiver",
                "runs_for_tag_project",
                "runs_for_receiver",
                "hits_for_tag_project",
                "hits_for_receiver",
                "gps_for_tag_project",
                "gps_for_receiver",
                "metadata_for_tags",
                "metadata_for_receivers",
                "tags_for_ambiguities",
                "size_of_update_for_tag_project",
                "size_of_update_for_receiver",
                ## and these administrative (local-use-only) apps, not reverse proxied
                ## from the internet at large
                "_shutdown"
                )

#' authenticate_user return a list of projects and receivers the user is authorized to receive data for
#'
#' This is an app used by the Rook server launched by \code{\link{dataServer}}
#' Params are passed as a url-encoded field named 'json' in the http POST request.
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

    if (tracing)
        browser()

    ts_req <<- as.numeric(Sys.time())

    res = Rook::Response$new()
    rv = NULL
    sendHeader(res)

    tryCatch({
        json = parent.frame()$postBody["json"]
        cat(format(Sys.time(), "%Y-%m-%dT%H-%M-%S"), ": authenticate_user: ", json, '\n', sep="", file=stderr())
        json = fromJSON(json)
    }, error = function(e) {
        rv <<- list(error="request is missing a json field or it has invalid JSON")
    })
    if (is.null(rv)) {
        username <- json$user
        password <- json$password

        motusReq = toJSON(list(
            date = format(Sys.time(), "%Y%m%d%H%M%S"),
            login = username,
            pword = password,
            type = "csv"),
            auto_unbox = TRUE)

        tryCatch({
            resp = getForm(motusServer:::MOTUS_API_USER_VALIDATE, json=motusReq, curl=Curl) %>% fromJSON
            ## generate a new authentication token for this user
            rv = list(
                authToken = unclass(RCurl::base64(readBin("/dev/urandom", raw(), n=ceiling(OPT_TOKEN_BITS / 8)))),
                expiry = as.numeric(Sys.time()) + OPT_AUTH_LIFE,
                userID = resp$userID,
                projects = resp$projects,
                receivers = NULL
            )

            ## add the auth info to the database for lookup by token
            ## we're using replace into to cover the 0-probability case where token has been used before.
            AuthDB("replace into auth (token, expiry, userID, projects) values (:token, :expiry, :userID, :projects)",
                   token = rv$authToken,
                   expiry = rv$expiry,
                   userID = rv$userID,
                   projects = rv$projects %>% toJSON (auto_unbox=TRUE) %>% unclass
                   )
            ## delete any expired tokens for user, while we're here.
            AuthDB("delete from auth where expiry < :now and userID = :userID",
                   now = as.numeric(Sys.time()),
                   userID = rv$userID)
        },
        error = function(e) {
            rv <<- list(error=paste("query to main motus server failed"))
        })
    }
    res$body = makeBody(rv)
    res$finish()
}

#' validate a request by looking up its token, failing gracefully
#'
#' @param json named list with at least these items:
#' \itemize{
#' \item authToken authorization token
#' \item projectID (optional) projectID
#' }
#'
#' @param res the rook result object
#'
#' @param needProjectID logical; if TRUE, a projectID to which the user
#' has permission must be in \code{json}; default:  TRUE
#'
#' @return if \code{authToken} represents a valid unexpired token, and needProjectID is FALSE or projectID is
#' a project for which the user is authorized, returns
#' a list with these items:
#' \itemize{
#' \item userID integer user ID
#' \item projects integer vector of *all* project IDs user has permission to
#' \item projectID the projectID specified in the request (and it is guaranteed the user has permission to this project)
#' }
#' Otherwise, send a JSON-formatted reply with the single item "error": "authorization failed"
#' and return NULL.

validate_request = function(json, res, needProjectID=TRUE) {

    ts_req <<- as.numeric(Sys.time())

    okay = TRUE

    openMotusDB() ## ensure connection is still valid after a possibly long time between requests

    authToken = (json$authToken %>% as.character)[1]
    projectID = (json$projectID %>% as.integer)[1]
    now = as.numeric(Sys.time())
    rv = AuthDB("
select
   userID,
   (select
      group_concat(key, ',')
    from
      json_each(projects)
   ) as projects,
   expiry
from
   auth
where
   token=:token",
token = authToken)
    if (! isTRUE(nrow(rv) > 0)) {
        ## authToken invalid
        okay = FALSE
        msg = "token invalid"
    } else if (all(rv$expiry < now)) {
        ## authToken expired
        okay = FALSE
        msg = "token expired"
    } else  {
        rv = list(userID=rv$userID, projects = scan(text=rv$projects, sep=",", quiet=TRUE), projectID=projectID)
        if (needProjectID && ! isTRUE(length(projectID) == 1 && projectID %in% rv$projects)) {
            ## user not authorized for project
            okay = FALSE
            msg = "not authorized for project"
        }
    }
    if (! okay) {
        sendHeader(res)
        sendError(res, msg)
        rv = NULL
    }
    return(rv)
}

#' make the body for a reply
#' converts a list or data.frame to json using toJSON with options:
#' \itemize{
#' \item auto_unbox=TRUE
#' \item dataframe="columns"
#' }
#' then compresses the result
#' with memCompress and method "bzip2"
#'
#' @param x list or data.frame to encode and compress
#'
#' @return a raw vector

makeBody = function(x) {
    cat("Request time: ", as.numeric(Sys.time()) - ts_req, "\n", file=stderr())
    memCompress(toJSON(x, auto_unbox=TRUE, dataframe="columns"), "bzip2")
}

#' send the header for a reply
#' @param res Rook::Response object
#' @return no return value
#'
#' @details the reply will always be a bzip2-compressed JSON-encoded value.
#' We also disable caching.
#'
sendHeader = function(res) {
    res$header("Cache-control", "no-cache")
    res$header("Content-type", "application/json")
    res$header("Content-Encoding", "bzip2")
}

#' send an error as the reply
#' @param res Rook::Response object
#' @param error character vector with error message(s)
#' @return no return value

sendError = function(res, error) {
    res$body = makeBody(list(error=error))
}

#' get deviceIDs for receiver serial numbers
#'
#' @param serno character vector of serial numbers
#'
#' @return a list with these vector items:
#'    \itemize{
#'       \item serno; character receiver serial numbers
#'       \item deviceID; integer device ID
#'    }

deviceID_for_receiver = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    serno = json$serno %>% as.character

    if (is.null(auth) || length(serno) == 0)
        return(res$finish())

    sendHeader(res)

    ## select deviceIDs for those receivers deployed by projects the user has permissions to

    MetaDB("create temporary table if not exists tempSernos (serno text)")
    MetaDB("delete from tempSernos")
    dbWriteTable(MetaDB$con, "tempSernos", data.frame(serno=serno), append=TRUE, row.names=FALSE)

    query = sprintf("
select
    t1.serno,
    t2.deviceID
from
   tempSernos as t1
   join recvDeps as t2 on t1.serno=t2.serno
where
   t2.projectID in (%s)
group by t2.serno
", paste(auth$projects, collapse=","))

    devIds = MetaDB(query)
    res$body = makeBody(devIds)
    res$finish()
}

#' get receivers for a project
#'
#' @param projectID; integer scalar project ID
#'
#' @return a list with these vector items:
#'    \itemize{
#'       \item projectID; integer ID of project that deployed the receiver
#'       \item serno; character serial number, e.g. "SG-1214BBBK3999", "Lotek-8681"
#'       \item receiverType; character "SENSORGNOME" or "LOTEK"
#'       \item deviceID; integer device ID (internal to motus)
#'       \item status; character deployment status
#'       \item name; character; typically a site name
#'       \item fixtureType; character; what is the receiver mounted on?
#'       \item latitude; numeric (initial) location, degrees North
#'       \item longitude; numeric (initial) location, degrees East
#'       \item elevation; numeric (initial) location, metres ASL
#'       \item isMobile; integer non-zero means a mobile deployment
#'       \item tsStart; numeric; timestamp of deployment start
#'       \item tsEnd; numeric; timestamp of deployment end, or NA if ongoing
#'    }

receivers_for_project = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    ## select all deployments of the receivers from the specified project

    query = sprintf("
select
    t1.projectID,
    t1.serno,
    t1.receiverType,
    t1.deviceID,
    t1.status,
    t1.name,
    t1.fixtureType,
    t1.latitude,
    t1.longitude,
    t1.elevation,
    t1.isMobile,
    t1.tsStart,
    t1.tsEnd
from
   recvDeps as t1
where
   t1.projectID =%d
", auth$projectID)

    recvDeps = MetaDB(query)
    res$body = makeBody(recvDeps)
    res$finish()
}


#' get batches for a tag project
#'
#' @param projectID integer project ID
#' @param batchID integer batchID; only batches with larger batchID are returned
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_tag_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    batchID = (json$batchID %>% as.integer)[1]
    if (!isTRUE(is.finite(batchID)))
        batchID = 0

    ## select batches for which there's an overlapping run of a tag deployed
    ## by the given project

    query = sprintf("
select
   t1.batchID,
   t1.motusDeviceID,
   t1.monoBN,
   t1.tsStart,
   t1.tsEnd,
   t1.numHits,
   t1.ts,
   t1.motusUserID,
   t1.motusProjectID,
   t1.motusJobID
from
   batches as t1
where
   t1.batchID > %d
   and
   exists (
      select
         *
      from
         batchRuns as t2
      join
         runs as t3 on t3.runID=t2.runID
      where
         t2.batchID=t1.batchID
         and t3.tagDepProjectID = %d
   )
order by
   t1.batchID
limit %d
",
batchID, auth$projectID, MAX_ROWS_PER_REQUEST)
    rv = MotusDB(query)
    res$body = makeBody(rv)
    res$finish()
}


#' get batches for a receiver
#'
#' @param deviceID integer device ID
#' @param batchID integer batchID; only batches with larger batchID are returned
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_receiver = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    deviceID = (json$deviceID %>% as.integer)[1]
    if (!isTRUE(is.finite(deviceID))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    batchID = (json$batchID %>% as.integer)[1]
    if (!isTRUE(is.finite(batchID)))
        batchID = 0

    ## select batches for a receiver that begin during one of the project's deployments
    ## of that receiver  (we assume a receiver batch is entirely in a deployment; i.e.
    ## that receivers get rebooted at least once between deployments to different
    ## projects).

    query = sprintf("
select
   t1.batchID,
   t1.motusDeviceID,
   t1.monoBN,
   t1.tsStart,
   t1.tsEnd,
   t1.numHits,
   t1.ts,
   t1.motusUserID,
   t1.motusProjectID,
   t1.motusJobID
from
   batches as t1
where
   t1.batchID > %d
   and t1.motusDeviceID = %d
   and t1.recvDepProjectID in (%s)
order by
   t1.batchID
limit %d
",
batchID, deviceID, paste(auth$projects, collapse=","), MAX_ROWS_PER_REQUEST)
    rv = MotusDB(query)
    res$body = makeBody(rv)
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

    MAX_ROWS_PER_REQUEST = 10000
    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    batchID = (json$batchID %>% as.integer)[1]
    runID = (json$runID %>% as.integer)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(runID))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## get all runs of a tag within a deployment of that tag by the
    ## given project that overlap the given batch

    query = sprintf("
select
   t1.runID,
   t1.batchIDbegin,
   t1.tsBegin,
   t1.tsEnd,
   t1.done,
   t1.motusTagID,
   t1.ant,
   t1.len
from
   runs as t1
   join batchRuns as t2 on t1.runID=t2.runID
where
   t2.batchID = %d
   and t1.runID > %d
   and t1.tagDepProjectID = %d
order by
   t1.runID
limit %d
",
batchID, runID, auth$projectID, MAX_ROWS_PER_REQUEST)
    rv = MotusDB(query)
    res$body = makeBody(rv)
    res$finish()
}

#' get all runs from a batch for a receiver
#'
#' @param batchID integer batchID
#' @param runID integer ID of largest run already obtained
#'
#' @return a data frame with the same schema as the runs table, but JSON-encoded as a list of columns

runs_for_receiver = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    batchID = (json$batchID %>% as.integer)[1]
    runID = (json$runID %>% as.integer)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(runID))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate runs

    query = sprintf("
select
   t1.runID,
   t1.batchIDbegin,
   t1.tsBegin,
   t1.tsEnd,
   t1.done,
   t1.motusTagID,
   t1.ant,
   t1.len
from
   runs as t1
   join batchRuns as t2 on t2.runID = t1.runID
   join batches as t3 on t3.batchID=t2.batchID
where
   t1.runID > %d
   and t2.batchID = %d
   and t3.recvDepProjectID in (%s)
order by
   t1.runID
limit %d
",
runID, batchID, paste(auth$projects, collapse=","), MAX_ROWS_PER_REQUEST)
    rv = MotusDB(query)
    res$body = makeBody(rv)
    res$finish()
}

#' get hits by tag project from a batch
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param hitID integer ID of largest hit already obtained
#'
#' @return a data frame with the same schema as the hits table, but JSON-encoded as a list of columns

hits_for_tag_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    batchID = (json$batchID %>% as.integer)[1]
    hitID = (json$hitID %>% as.integer)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(hitID))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate hits

    query = sprintf("
select
   t1.hitID,
   t1.runID,
   t1.batchID,
   t1.ts,
   t1.sig,
   t1.sigSD,
   t1.noise,
   t1.freq,
   t1.freqSD,
   t1.slop,
   t1.burstSlop
from
   hits as t1
   join runs as t2 on t2.runID = t1.runID
   join batchRuns as t3 on t3.runID = t2.runID
where
   t1.hitID > %d
   and t3.batchID = %d
   and t2.tagDepProjectID = %d
order by
   t1.hitID
limit %d
",
hitID, batchID, auth$projectID, MAX_ROWS_PER_REQUEST)
    rv = MotusDB(query)
    res$body = makeBody(rv)
    res$finish()
}

#' get all hits from a batch for a receiver
#'
#' @param batchID integer batchID
#' @param hitID integer ID of largest hit already obtained
#'
#' @return a data frame with the same schema as the hits table, but JSON-encoded as a list of columns

hits_for_receiver = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    batchID = (json$batchID %>% as.integer)[1]
    hitID = (json$hitID %>% as.integer)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(hitID))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate hits

    query = sprintf("
select
   t1.hitID,
   t1.runID,
   t1.batchID,
   t1.ts,
   t1.sig,
   t1.sigSD,
   t1.noise,
   t1.freq,
   t1.freqSD,
   t1.slop,
   t1.burstSlop
from
   hits as t1
   join batches as t2 on t2.batchID=t1.batchID
where
   t1.hitID > %d
   and t1.batchID = %d
   and t2.recvDepProjectID in (%s)
order by
   t1.hitID
limit %d
",
hitID, batchID, paste(auth$projects, collapse=","), MAX_ROWS_PER_REQUEST)
    rv = MotusDB(query)
    res$body = makeBody(rv)
    res$finish()
}

#' get all GPS fixes from a batch "relevant to" detections of tags
#' from a project.
#'
#' @param projectID integer project ID of tags of interest
#' @param batchID integer batchID
#' @param ts numeric timestamp of latest fix already obtained
#'
#' @details This is given a permissive interpretation: all GPS fixes
#'     from 1 hour before the first detection of a project tag to 1
#'     hour after the last detection of a project tag in the given
#'     batch are returned.  This might return GPS fixes for long
#'     periods where no tags from the project were detected, if a
#'     batch has a few early and a few late detections of the
#'     project's tags.
#'
#' @return a data frame with the same schema as the gps table, but JSON-encoded as a list of columns

gps_for_tag_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    batchID = (json$batchID %>% as.integer)[1]
    ts = (json$ts %>% as.numeric)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(ts))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate gps records
    ## grab runs in the given batch for tags in the given project,
    ## pull out gps fixes for those runs, and remove duplicates

    query = sprintf("
select
    t1.ts,
    t1.gpsts,
    t1.batchID,
    t1.lat,
    t1.lon,
    t1.alt
from
   gps as t1
   join (
      select
         min(t3.tsBegin) as tsBegin,
         max(t3.tsEnd) as tsEnd
      from
         batchRuns as t2
         join runs as t3 on t3.runID = t2.runID
      where
         t2.batchID = %d
         and t3.tagDepProjectID = %d
    ) as t4
where
   t1.batchID = %d
   and t1.ts > %f
   and t1.ts >= t4.tsBegin - 3600
   and t1.ts <= t4.tsEnd + 3600
order by
   t1.ts
limit %d
",
batchID, auth$projectID, batchID, ts, MAX_ROWS_PER_REQUEST)
    rv = MotusDB(query)
    res$body = makeBody(rv)
    res$finish()
}

#' get all GPS fixes from a batch
#'
#' @param batchID integer batchID
#' @param ts numeric timestamp of latest fix already obtained
#'
#' @return a data frame with the same schema as the gps table, but JSON-encoded as a list of columns

gps_for_receiver = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    batchID = (json$batchID %>% as.integer)[1]
    ts = (json$ts %>% as.numeric)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(ts))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## pull gps records provided the batch is for a deployment of the
    ## receiver by one of the projects the user is authorized for

    query = sprintf("
select
    t1.ts,
    t1.gpsts,
    t1.batchID,
    t1.lat,
    t1.lon,
    t1.alt
from
   gps as t1
   join batches as t2 on t2.batchID=t1.batchID
where
   t2.batchID = %d
   and t2.recvDepProjectID in (%s)
   and t1.ts > %f
order by
   t1.ts
limit %d
",
batchID, paste(auth$projects, collapse=","), ts, MAX_ROWS_PER_REQUEST)
    rv = MotusDB(query)
    res$body = makeBody(rv)
    res$finish()
}

#' get metadata for tags
#'
#' @param motusTagIDs integer vector of tag IDs for which metadata are sought
#'
#' @return a list with these items
#'
#' \itemize{
#'    \item tags; a list with these vector items:
#'    \itemize{
#'       \item tagID; integer tag ID
#'       \item projectID; integer project ID (who registered the tag)
#'       \item mfgID; character manufacturer tag ID
#'       \item type; character "ID" or "BEEPER"
#'       \item codeSet; character e.g. "Lotek3", "Lotek4"
#'       \item manufacturer; character e.g. "Lotek"
#'       \item model; character e.g. "NTQB-3-1"
#'       \item lifeSpan; integer estimated tag lifeSpan, in days
#'       \item nomFreq; numeric nominal frequency of tag, in MHz
#'       \item offsetFreq; numeric estimated offset frequency of tag, in kHz
#'       \item bi; numeric burst interval or period of tag, in seconds
#'       \item pulseLen; numeric length of tag pulses, in ms (not applicable to all tags)
#'    }
#'    \item tagDeps; a list with these vector items:
#'    \itemize{
#'       \item tagID; integer motus tagID
#'       \item deployID; integer tag deployment ID (internal to motus)
#'       \item projectID; integer motus ID of project deploying tag
#'       \item tsStart; numeric timestamp of start of deployment
#'       \item tsEnd; numeric timestamp of end of deployment
#'       \item deferSec; integer deferred activation period, in seconds (0 for most tags).
#'       \item speciesID; integer motus species ID code
#'       \item markerType; character type of marker on organism; e.g. leg band
#'       \item markerNumber; character details of marker; e.g. leg band code
#'       \item latitude; numeric deployment location, degrees N (negative is S)
#'       \item longitude; numeric deployment location, degrees E (negative is W)
#'       \item elevation; numeric deployment location, metres ASL
#'       \item comments; character possibly JSON-formatted list of additional metadata
#'    }
#'    \item species; a list with these vector items:
#'    \itemize{
#'       \item id; integer species ID,
#'       \item english; character; English species name
#'       \item french; character; French species name
#'       \item scientific; character; scientific species name
#'       \item group; character; higher-level taxon
#'    }
#'    \item projs; a list with these columns:
#'    \itemize{
#'       \item id; integer motus project id
#'       \item name; character full name of motus project
#'       \item label; character short label for motus project; e.g. for use in plots
#'    }
#' }
#'
#' @note only metadata which are public, or which are from projects
#'     the user has permission to are returned.

metadata_for_tags = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    motusTagIDs = json$motusTagIDs %>% as.integer

    if (!isTRUE(all(is.finite(motusTagIDs)))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## determine which projects have tag deployments overlapping with public
    ## metadata (among the given tagIDs)

    MetaDB("create temporary table if not exists tempQueryTagIDs (tagID integer)")
    MetaDB("delete from tempQueryTagIDs")
    dbWriteTable(MetaDB$con, "tempQueryTagIDs", data.frame(tagID=motusTagIDs), append=TRUE, row.names=FALSE)
    projs = MetaDB("
select
   t3.id as id,
   t3.name as name,
   t3.label as label
from
   tempQueryTagIds as t1
   join tagDeps as t2 on t1.tagID = t2.tagID
   join projs as t3 on t2.projectID = t3.id
where
   t3.tagsPermissions = 2
")
    ## append projects user has access to via motus permissions
    projIDs = unique(c(projs$id, auth$projects))

    ## select all deployments of these tags from the permitted projects

    query = sprintf("
select
   t1.tagID,
   t1.deployID,
   t1.projectID,
   t1.tsStart,
   t1.tsEnd,
   t1.deferSec,
   t1.speciesID,
   t1.markerType,
   t1.markerNumber,
   t1.latitude,
   t1.longitude,
   t1.elevation,
   t1.comments
from
   tagDeps as t1
where
   t1.projectID in (%s)
   and t1.tagID in (%s)
", paste(projIDs, collapse=","), paste(motusTagIDs, collapse=","))

    tagDeps = MetaDB(query)

    speciesIDs = unique(tagDeps$speciesID)
    speciesIDs = speciesIDs[! is.na(speciesIDs)]

    query = sprintf("
select
   t1.tagID,
   t1.projectID,
   t1.mfgID,
   t1.type,
   t1.codeSet,
   t1.manufacturer,
   t1.model,
   t1.lifeSpan,
   t1.nomFreq,
   t1.offsetFreq,
   t1.period as bi,
   t1.pulseLen
from
   tags as t1
where
   t1.tagID in (%s)
", paste(tagDeps$tagID, collapse=","))

    tags = MetaDB(query)

    query = sprintf("
select
   t1.id,
   t1.english,
   t1.french,
   t1.scientific,
   t1.\"group\"
from
   species as t1
where
   t1.id in (%s)
", paste(speciesIDs, collapse=","))

    species = MetaDB(query)
    res$body = makeBody(list(tags=tags, tagDeps=tagDeps, species=species, projs=projs))
    res$finish()
}

#' get metadata for receivers
#'
#' @param deviceIDs; integer vector of motus device IDs; receiver
#'     metadata will only be returned for receivers whose project has
#'     indicated their metadata are public, or receivers in one of the
#'     projects the user has permissions to.
#'
#' @return a list with these items:
#' \itemize{
#'    \item recvDeps; a list with these vector items:
#'    \itemize{
#'       \item deployID; integer deployment ID (internal to motus, but links to antDeps)
#'       \item projectID; integer ID of project that deployed the receiver
#'       \item serno; character serial number, e.g. "SG-1214BBBK3999", "Lotek-8681"
#'       \item receiverType; character "SENSORGNOME" or "LOTEK"
#'       \item deviceID; integer device ID (internal to motus)
#'       \item status; character deployment status
#'       \item name; character; typically a site name
#'       \item fixtureType; character; what is the receiver mounted on?
#'       \item latitude; numeric (initial) location, degrees North
#'       \item longitude; numeric (initial) location, degrees East
#'       \item elevation; numeric (initial) location, metres ASL
#'       \item isMobile; integer non-zero means a mobile deployment
#'       \item tsStart; numeric; timestamp of deployment start
#'       \item tsEnd; numeric; timestamp of deployment end, or NA if ongoing
#'    }
#'    \item antDeps; a list with these vector items:
#'    \itemize{
#'       \item deployID; integer, links to deployID in recvDeps table
#'       \item port; integer, which receiver port (USB for SGs, BNC for Lotek) the antenna is connected to
#'       \item antennaType; character; e.g. "Yagi-5", "omni"
#'       \item bearing; numeric compass angle at which antenna is pointing; degrees clockwise from magnetic north
#'       \item heightMeters; numeric height of main antenna element above ground
#'       \item cableLengthMeters; numeric length of coaxial cable from antenna to receiver, in metres
#'       \item cableType: character; type of cable; e.g. "RG-58"
#'       \item mountDistanceMeters; numeric distance of mounting point from receiver, in metres
#'       \item mountBearing; numeric compass angle from receiver to antenna mount; degrees clockwise from magnetic north
#'       \item polarization2; numeric angle giving tilt from "normal" position, in degrees
#'       \item polarization1; numeric angle giving rotation of antenna about own axis, in degrees.
#'    }
#'    \item projs; a list with these columns:
#'    \itemize{
#'       \item id; integer motus project id
#'       \item name; character full name of motus project
#'       \item label; character short label for motus project; e.g. for use in plots
#'    }
#' }
#'
#' @note only metadata which are public, or which are from projects
#'     the user has permission to are returned.

metadata_for_receivers = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    deviceIDs = json$deviceIDs %>% as.integer

    if (!isTRUE(all(is.finite(deviceIDs)))) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## determine which projects have receiver deployments overlapping with public
    ## metadata (among the given tagIDs)

    MetaDB("create temporary table if not exists tempQueryDeviceIDs (deviceID integer)")
    MetaDB("delete from tempQueryDeviceIDs")
    dbWriteTable(MetaDB$con, "tempQueryDeviceIDs", data.frame(deviceID=deviceIDs), append=TRUE, row.names=FALSE)
    projs = MetaDB("
select
   t3.id as id,
   t3.name as name,
   t3.label as label
from
   tempQueryDeviceIds as t1
   join recvDeps as t2 on t1.deviceID = t2.deviceID
   join projs as t3 on t2.projectID = t3.id
where
   t3.sensorsPermissions = 2
")
    ## append projects user has access to via motus permissions
    projIDs = unique(c(projs$id, auth$projects))

    ## select all deployments of the receivers from the permitted projects

    query = sprintf("
select
    t1.deployID,
    t1.projectID,
    t1.serno,
    t1.receiverType,
    t1.deviceID,
    t1.status,
    t1.name,
    t1.fixtureType,
    t1.latitude,
    t1.longitude,
    t1.elevation,
    t1.isMobile,
    t1.tsStart,
    t1.tsEnd
from
   recvDeps as t1
where
   t1.projectID in (%s)
   and t1.deviceID in (%s)
", paste(projIDs, collapse=","), paste(deviceIDs, collapse=","))

    recvDeps = MetaDB(query)

    query = sprintf("
select
    t2.deployID,
    t2.port,
    t2.antennaType,
    t2.bearing,
    t2.heightMeters,
    t2.cableLengthMeters,
    t2.cableType,
    t2.mountDistanceMeters,
    t2.mountBearing,
    t2.polarization2,
    t2.polarization1
from
   recvDeps as t1
   join antDeps as t2 on t1.deployID = t2.deployID
where
   t1.projectID in (%s)
   and t1.deviceID in (%s)
", paste(projIDs, collapse=","), paste(deviceIDs, collapse=","))

    antDeps = MetaDB(query)
    res$body = makeBody(list(recvDeps=recvDeps, antDeps=antDeps, projs=projs))
    res$finish()
}

#' get motus tagIDs for ambiguity IDs
#'
#' @param ambigIDs integer vector of ambiguity IDs, which are all negative
#'
#' @return a list with these vector items:
#' \itemize{
#'    \item ambigID; negative integer tag ambiguity ID
#'    \item motusTagID1; positive integer motus tag ID
#'    \item motusTagID2; positive integer motus tag ID
#'    \item motusTagID3; positive integer motus tag ID or null
#'    \item motusTagID4; positive integer motus tag ID or null
#'    \item motusTagID5; positive integer motus tag ID or null
#'    \item motusTagID6; positive integer motus tag ID or null
#' }

tags_for_ambiguities = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    ambigIDs = json$ambigIDs %>% as.integer

    if (!isTRUE(all(is.finite(ambigIDs)) && all(ambigIDs < 0)) && length(ambigIDs) > 0) {
        sendError(res, "invalid parameter(s)")
        return(res$finish())
    }

    ## to work around invalid syntax of '()', use an invalid ID
    ## to get a result with zero rows.

    if (length(ambigIDs) == 0)
        ambigIDs = 0
    query = sprintf("
select
   t1.ambigID,
   t1.motusTagID1,
   t1.motusTagID2,
   t1.motusTagID3,
   t1.motusTagID4,
   t1.motusTagID5,
   t1.motusTagID6
from
   tagAmbig as t1
where
   t1.ambigID in (%s)
order by
   t1.ambigID desc
", paste(ambigIDs, collapse=","))

    ambig = MotusDB(query)
    res$body = makeBody(ambig)
    res$finish()
}

#' get count of update items for a tag project
#'
#' @param projectID integer project ID
#' @param batchID integer batchID; only batches with larger batchID are considered
#'
#' @return a list with these items:
#' \itemize{
#' \item numBatches
#' \item numRuns
#' \item numHits
#' \item numGPS
#' }

### FIXME #### size_of_update*

size_of_update_for_tag_project = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    batchID = json$batchID %>% as.integer
    if (!isTRUE(is.finite(batchID)))
        batchID = 0

    ## all in one query: get number of batches, runs, hits and GPS fixes
    ## not yet seen but for this tag project

    query = sprintf("
select
   count(*) as numBatches,
   sum(numRuns) as numRuns,
   sum(numHits) as numHits,
   sum(numGPS) as numGPS
from
   (select
       t1.batchID as bid,
       numRuns,
       numHits,
       count(*) as numGPS
    from
       (select
           batchIDbegin as batchID,
           count(*) as numRuns,
           sum(len) as numHits,
           min(tsBegin) as tsStart,
           max(tsEnd) as tsEnd
        from
           runs
        where
           batchIDbegin > %d
           and tagDepProjectID = %d
        group by
           batchIDbegin
       ) as t1
       left outer join gps as t2
          on t1.batchID=t2.batchID and (t2.ts >=t1.tsStart -3600 and t2.ts <= t1.tsEnd + 3600)
    group by
       t1.batchID
   ) as t3
",
batchID, auth$projectID)
    rv = MotusDB(query)

    rv$numBytes = with(rv,
        110 + 90 * numBatches +
        75 + 64 * numRuns +
        80 + 100 * numHits +
        50 + 52 * numGPS)

    res$body = makeBody(unclass(rv))
    res$finish()
}

#' get count of update items for a receiver
#'
#' @param deviceID integer motus device ID
#' @param batchID integer batchID; only batches with larger batchID are considered
#'
#' @return a list with these items:
#' \itemize{
#' \item numBatches
#' \item numRuns
#' \item numHits
#' \item numGPS
#' }

size_of_update_for_receiver = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])
    res = Rook::Response$new()

    if (tracing)
        browser()

    auth = validate_request(json, res, needProjectID=FALSE)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    deviceID = json$deviceID %>% as.integer
    if (!isTRUE(is.finite(deviceID)))
        return(res$finish())
    batchID = json$batchID %>% as.integer
    if (!isTRUE(is.finite(batchID)))
        batchID = 0

    ## count batches for a receiver that begin during one of the project's deployments
    ## of that receiver  (we assume a receiver batch is entirely in a deployment; i.e.
    ## that receivers get rebooted at least once between deployments to different
    ## projects).

    query = sprintf("
select
   count(*) as numBatches,
   sum(numRuns) as numRuns,
   sum(numHits) as numHits,
   sum(numGPS) as numGPS
from
   (select
       t1.batchID,
       count(*) as numRuns,
       sum(t2.len) as numHits,
       (select
           count(*)
        from
           gps as t3
        where
           t3.batchID=t1.batchID
       ) as numGPS
       from
          batches as t1
          join runs as t2 on t2.batchIDbegin=t1.batchId
       where
          t1.batchID > %d
          and t1.motusDeviceID = %d
          and t1.recvDepProjectID in (%s)
       group by t1.batchID
    ) as t3
",
batchID, deviceID, paste(auth$projects, collapse=","))
    rv = MotusDB(query)

    rv$numBytes = with(rv,
        110 + 90 * numBatches +
        75 + 64 * numRuns +
        80 + 100 * numHits +
        50 + 52 * numGPS)

    res$body = makeBody(unclass(rv))
    res$finish()
}

#' shut down this server.  The leading '_', which requires the appname to be
#' quoted, marks this as an app that won't be exposed to the internet via
#' the apache reverse proxy

`_shutdown` = function(env) {
    res = Rook::Response$new()
    sendHeader(res)
    sendError(res, "data server shutting down")
    res$finish()
    q(save="no")
}
