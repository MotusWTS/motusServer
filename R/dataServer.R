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

allDataApps = c("authenticate_user",
 "batches_for_tag_project",
 "batches_for_receiver_project",
 "runs_for_tag_project",
 "runs_for_receiver_project",
 "hits_for_tag_project",
 "hits_for_receiver_project",
 "gps_for_tag_project",
 "gps_for_receiver_project",
 "metadata_for_tags",
 "metadata_for_receivers",
 "tags_for_ambiguities"
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

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json <- req$POST()[['json']] %>% fromJSON()
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
#' \item projects integer vector of project IDs user has permission to
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

sendError = function(res, error) {
    res$body = memCompress(toJSON(list(error=error), auto_unbox=TRUE), "gzip")
}


#' get batches for a tag project
#'
#' @param projectID integer project ID
#' @param batchID integer batchID; only batches with larger batchID are returned
#' @param countOnly logical return only the count of records
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_tag_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    if (!isTRUE(is.finite(batchID)))
        batchID = 0
    countOnly = isTRUE(json$countOnly)

    ## select batches that have a detection of a tag
    ## overlapping that tag's deployment by the given project

    query = sprintf("
select
   t3.batchID,
   t3.motusDeviceID as deviceID,
   t3.monoBN,
   t3.tsBegin,
   t3.tsEnd,
   t3.numHits,
   t3.ts
from
   tag_deployments as t1
   join runs as t2 on t1.motusTagID=t2.motusTagID
   join batches as t3 on t2.batchIDbegin=t3.batchID
where
   t1.projectID = %d
   and t1.tsStart <= t3.tsEnd
   and t3.tsBegin <= t1.tsEnd
   and t3.batchID > %d
group by
   t3.batchID
order by
   t3.batchID
",
projectID, batchID)
    if (countOnly) {
        query = sprintf("select count(*) as count from (%s) as _bogus", query)
    } else {
        query = sprintf("%s limit %d", query, MAX_ROWS_PER_REQUEST)
    }
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get batches for a receiver project
#'
#' @param projectID integer project ID
#' @param batchID integer batchID; only batches with larger batchID are returned
#' @param countOnly logical return only the count of records
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_receiver_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    if (!isTRUE(is.finite(batchID)))
        batchID = 0
    countOnly = isTRUE(json$countOnly)

    ## select batches for a receiver that begin during one of the project's deployments
    ## of that receiver  (we assume a receiver batch is entirely in a deployment; i.e.
    ## that receivers get rebooted at least once between deployments to different
    ## projects).

    query = sprintf("
select
   t2.batchID,
   t2.motusDeviceID as deviceID,
   t2.monoBN,
   t2.tsBegin,
   t2.tsEnd,
   t2.numHits,
   t2.ts
from
   receiver_deployments as t1
   join batches as t2 on t1.deviceID=t2.motusDeviceID
where
   t1.projectID = %d
   and t2.batchID > %d
   and ((t1.tsEnd is null and t2.tsBegin >= t1.tsStart)
     or (t1.tsStart <= t2.tsEnd and t2.tsBegin <= t1.tsEnd))
order by
   t2.batchID
",
projectID, batchID)
    if (countOnly) {
        query = sprintf("select count(*) as count from (%s) as _bogus", query)
    } else {
        query = sprintf("%s limit %d", query, MAX_ROWS_PER_REQUEST)
    }
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get runs by tag project from a batch
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param runID integer ID of largest run already obtained
#' @param countOnly logical return only the count of records
#'
#' @return a data frame with the same schema as the runs table, but JSON-encoded as a list of columns

runs_for_tag_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    runID = json$runID %>% as.integer
    countOnly = isTRUE(json$countOnly)

    if (!isTRUE(is.finite(projectID) && is.finite(batchID) && is.finite(runID))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    ## get all runs in a batch having a detection of a tag
    ## within a deployment of that tag by the given project

    ## For a batch B, a run R is "in" B means:
    ##     R.batchIDbegin == B
    ##  or R.batchIDend == B
    ##  or (R.batchIDend is null and R.batchIDbegin < B)

    query = sprintf("
select
   t2.runID,
   t2.batchIDbegin,
   t2.batchIDend,
   t2.motusTagID,
   t2.ant,
   t2.len
from
   batches as t1
   join runs as t2 on
      (t2.batchIDbegin = t1.batchID)
      or (t2.batchIDend = t1.batchID)
      or (t2.batchIDend is null and t2.batchIDbegin < t1.batchID)
   join tag_deployments as t3 on t2.motusTagID=t3.motusTagID
   join hits as t4 on t4.runID=t2.runID
where
   t1.batchID = %d
   and t2.runID > %d
   and t3.projectID = %d
   and t4.ts <= t3.tsEnd
   and t4.ts >= t3.tsStart
group by
   t2.runID
order by
   t2.runID
",
batchID, runID, projectID)
    if (countOnly) {
        query = sprintf("select count(*) as count from (%s) as _bogus", query)
    } else {
        query = sprintf("%s limit %d", query, MAX_ROWS_PER_REQUEST)
    }
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get all runs from a batch
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param runID integer ID of largest run already obtained
#' @param countOnly logical return only the count of records
#'
#' @return a data frame with the same schema as the runs table, but JSON-encoded as a list of columns

runs_for_receiver_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    runID = json$runID %>% as.integer
    countOnly = isTRUE(json$countOnly)

    if (!isTRUE(is.finite(projectID) && is.finite(batchID) && is.finite(runID))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate runs

    query = sprintf("
select
   t2.runID,
   t2.batchIDbegin,
   t2.batchIDend,
   t2.motusTagID,
   t2.ant,
   t2.len
from
   batches as t1
   join runs as t2 on
      (t2.batchIDbegin = t1.batchID)
      or (t2.batchIDend = t1.batchID)
      or (t2.batchIDend is null and t2.batchIDbegin < t1.batchID)
   join receiver_deployments as t3 on t1.motusDeviceID=t3.deviceID
where
   t1.batchID = %d
   and t2.runID > %d
   and t3.projectID = %d
   and ((t3.tsEnd is null and t1.tsBegin >= t3.tsStart)
     or (t1.tsBegin <= t3.tsEnd and t3.tsStart <= t1.tsEnd))
order by
   t2.runID
",
batchID, runID, projectID)
    if (countOnly) {
        query = sprintf("select count(*) as count from (%s) as _bogus", query)
    } else {
        query = sprintf("%s limit %d", query, MAX_ROWS_PER_REQUEST)
    }
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get hits by tag project from a batch
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param hitID integer ID of largest hit already obtained
#' @param countOnly logical return only the count of records
#'
#' @return a data frame with the same schema as the hits table, but JSON-encoded as a list of columns

hits_for_tag_project = function(env) {

    MAX_ROWS_PER_REQUEST = 50000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    hitID = json$hitID %>% as.integer
    countOnly = isTRUE(json$countOnly)

    if (!isTRUE(is.finite(projectID) && is.finite(batchID) && is.finite(hitID))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate hits

    query = sprintf("
select
   t4.hitID,
   t4.runID,
   t4.batchID,
   t4.ts,
   t4.sig,
   t4.sigSD,
   t4.noise,
   t4.freq,
   t4.freqSD,
   t4.slop,
   t4.burstSlop
from
   batches as t1
   join runs as t2 on t2.batchIDbegin=t1.batchID
   join hits as t4 on t4.runID=t2.runID
   join tag_deployments as t3 on t2.motusTagID=t3.motusTagID
where
   t1.batchID = %d
   and t4.hitID > %d
   and t3.projectID = %d
   and t4.ts <= t3.tsEnd
   and t4.ts >= t3.tsStart
order by
   t4.hitID
",
batchID, hitID, projectID)
    if (countOnly) {
        query = sprintf("select count(*) as count from (%s) as _bogus", query)
    } else {
        query = sprintf("%s limit %d", query, MAX_ROWS_PER_REQUEST)
    }
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get hits by receiver project from a batch (i.e. all hits from the batch)
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param hitID integer ID of largest hit already obtained
#' @param countOnly logical return only the count of records
#'
#' @return a data frame with the same schema as the hits table, but JSON-encoded as a list of columns

hits_for_receiver_project = function(env) {

    MAX_ROWS_PER_REQUEST = 50000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    hitID = json$hitID %>% as.integer
    countOnly = isTRUE(json$countOnly)

    if (!isTRUE(is.finite(projectID) && is.finite(batchID) && is.finite(hitID))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate hits

    query = sprintf("
select
   t2.hitID,
   t2.runID,
   t2.batchID,
   t2.ts,
   t2.sig,
   t2.sigSD,
   t2.noise,
   t2.freq,
   t2.freqSD,
   t2.slop,
   t2.burstSlop
from
   receiver_deployments as t3
   join batches as t1 on t3.deviceID = t1.motusDeviceID
   join hits as t2 on t2.batchID=t1.batchID
where
   t1.batchID = %d
   and t3.projectID = %d
   and t2.hitID > %d
   and ((t3.tsEnd is null and t1.tsBegin >= t3.tsStart)
     or (t1.tsBegin <= t3.tsEnd and t3.tsStart <= t1.tsEnd))
order by
   t2.hitID
",
batchID, projectID, hitID)
    if (countOnly) {
        query = sprintf("select count(*) as count from (%s) as _bogus", query)
    } else {
        query = sprintf("%s limit %d", query, MAX_ROWS_PER_REQUEST)
    }
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get all GPS fixes from a batch "near" to detections of tags from a project.
#'
#' @param projectID integer project ID of tags of interest
#' @param batchID integer batchID
#' @param ts numeric timestamp of latest fix already obtained
#' @param countOnly logical return only the count of records
#'
#' @return a data frame with the same schema as the gps table, but JSON-encoded as a list of columns

gps_for_tag_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    ts = json$ts %>% as.numeric
    countOnly = isTRUE(json$countOnly)

    if (!isTRUE(is.finite(projectID) && is.finite(batchID) && is.finite(ts))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate gps records

    query = sprintf("
select
    t.ts,
    t.gpsts,
    t.batchID,
    t.lat,
    t.lon,
    t.alt
from
   gps as t
   join (
      select
         distinct 3600 * (floor(t2.ts / 3600) + dt.dt) as hour
      from
         runs as t3
         join tag_deployments as t4 on t4.motusTagID=t3.motusTagID
         join hits as t2 on t2.runID = t3.runID
         join (select -1 as dt union select 0 as dt union select 1 as dt) as dt
      where
         t3.batchIDbegin = %d
         and t4.projectID = %d
      order by
         hour
    ) as t2 on t.ts >= t2.hour and t.ts < t2.hour + 3600
where
   t.batchID = %d
   and t.ts > %f
order by
   t.ts
",
batchID, projectID, batchID, ts)
    if (countOnly) {
        query = sprintf("select count(*) as count from (%s) as _bogus", query)
    } else {
        query = sprintf("%s limit %d", query, MAX_ROWS_PER_REQUEST)
    }
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get all GPS fixes from a batch
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param ts numeric timestamp of latest fix already obtained
#' @param countOnly logical return only the count of records
#'
#' @return a data frame with the same schema as the gps table, but JSON-encoded as a list of columns

gps_for_receiver_project = function(env) {

    MAX_ROWS_PER_REQUEST = 10000
    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    projectID = json$projectID %>% as.integer
    batchID = json$batchID %>% as.integer
    ts = json$ts %>% as.numeric
    countOnly = isTRUE(json$countOnly)

    if (!isTRUE(is.finite(projectID) && is.finite(batchID) && is.finite(ts))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    ## pull out appropriate gps records

    query = sprintf("
select
    t2.ts,
    t2.gpsts,
    t2.batchID,
    t2.lat,
    t2.lon,
    t2.alt
from
   receiver_deployments as t3
   join batches as t1 on t3.deviceID = t1.motusDeviceID
   join gps as t2 on t2.batchID=t1.batchID
where
   t1.batchID = %d
   and t3.projectID = %d
   and t2.ts > %f
   and ((t3.tsEnd is null and t1.tsBegin >= t3.tsStart)
     or (t1.tsBegin <= t3.tsEnd and t3.tsStart <= t1.tsEnd))
order by
   t2.ts
",
batchID, projectID, ts)
    if (countOnly) {
        query = sprintf("select count(*) as count from (%s) as _bogus", query)
    } else {
        query = sprintf("%s limit %d", query, MAX_ROWS_PER_REQUEST)
    }
    rv = MotusDB(query)
    res$body = memCompress(toJSON(rv, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}

#' get metadata for tags
#'
#' @param motusTagIDs integer vector of tag IDs for which metadata are sought
#'
#' @return a list with these items
#'
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
#' }
#'
#' @note only metadata which are public, or which are from projects
#'     the user has permission to are returned.

metadata_for_tags = function(env) {

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    motusTagIDs = json$motusTagIDs %>% as.integer

    if (!isTRUE(all(is.finite(motusTagIDs)))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    ## determine which projects have tag deployments overlapping with public
    ## metadata (among the given tagIDs)

    MetaDB("create temporary table if not exists tempQueryTagIDs (tagID integer)")
    MetaDB("delete from tempQueryTagIDs")
    dbWriteTable(MetaDB$con, "tempQueryTagIDs", data.frame(tagID=motusTagIDs), append=TRUE, row.names=FALSE)
    projs = MetaDB("
select
   distinct projectID
from
   tempQueryTagIds as t1
   join tagDeps as t2 on t1.tagID = t2.tagID
   join projs as t3 on t2.projectID = t3.id
where
   t3.tagsPermissions = 2
") [[1]]
    ## append projects user has access to via motus permissions
    projs = unique(c(projs, auth$projects))

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
", paste(projs, collapse=","), paste(motusTagIDs, collapse=","))

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
   t1.bi,
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
    res$body = memCompress(toJSON(list(tags=tags, tagDeps=tagDeps, species=species), auto_unbox=TRUE, dataframe="columns"), "gzip")
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
#' }
#'
#' @note only metadata which are public, or which are from projects
#'     the user has permission to are returned.

metadata_for_receivers = function(env) {

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    deviceIDs = json$deviceIDs %>% as.integer

    if (!isTRUE(all(is.finite(deviceIDs)))) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

    ## determine which projects have receiver deployments overlapping with public
    ## metadata (among the given tagIDs)

    MetaDB("create temporary table if not exists tempQueryDeviceIDs (deviceID integer)")
    MetaDB("delete from tempQueryDeviceIDs")
    dbWriteTable(MetaDB$con, "tempQueryDeviceIDs", data.frame(deviceID=deviceIDs), append=TRUE, row.names=FALSE)
    projs = MetaDB("
select
   distinct projectID
from
   tempQueryDeviceIds as t1
   join recvDeps as t2 on t1.deviceID = t2.deviceID
   join projs as t3 on t2.projectID = t3.id
where
   t3.sensorsPermissions = 2
") [[1]]
    ## append projects user has access to via motus permissions
    projs = unique(c(projs, auth$projects))

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
", paste(projs, collapse=","), paste(deviceIDs, collapse=","))

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
", paste(projs, collapse=","), paste(deviceIDs, collapse=","))

    antDeps = MetaDB(query)
    res$body = memCompress(toJSON(list(recvDeps=recvDeps, antDeps=antDeps), auto_unbox=TRUE, dataframe="columns"), "gzip")
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

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    if (tracing)
        browser()
    json = req$POST()[['json']] %>% fromJSON()
    auth = validate_request(json, res)
    if (is.null(auth))
        return(res$finish())

    sendHeader(res)

    ambigIDs = json$ambigIDs %>% as.integer

    if (!isTRUE(all(is.finite(ambigIDs)) && all(ambigIDs < 0)) && length(ambigIDs) > 0) {
        sendError("invalid parameter(s)")
        return(res$finish())
    }

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
    res$body = memCompress(toJSON(ambig, auto_unbox=TRUE, dataframe="columns"), "gzip")
    res$finish()
}
