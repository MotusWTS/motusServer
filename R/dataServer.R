#' serve http requests for tag detection data
#'
#' @param port integer; local port on which to listen for requests
#' Default: 0xda7a
#'
#' @param tracing logical; if TRUE, run interactively, allowing local user
#' to enter commands.
#'
#' @param maxRows integer; the maximum number of rows to return for any query.
#' Default: 10000
#'
#' @return does not return; meant to be run as a server.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

dataServer = function(port=0xda7a, tracing=FALSE, maxRows=10000) {

    serverCommon()

    ## save maxRows in a global variable so methods can obtain it
    MAX_ROWS_PER_REQUEST <<- maxRows

    ## assign global MotusCon to be the low-level connection behind MotusDB, as some
    ## functions must us that

    tracing <<- tracing

    ## save server in a global variable in case we are tracing
    ## (weird assignment is because "Server" is already bound in Rook package,
    ## which is on our search path)

    .GlobalEnv$Server = Rhttpd$new()

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

allDataApps = c("api_info",
                "authenticate_user",
                "deviceID_for_receiver",
                "receivers_for_project",
                "batches_for_tag_project",
                "batches_for_receiver",
                "batches_for_all",
                "runs_for_tag_project",
                "runs_for_receiver",
                "hits_for_tag_project",
                "hits_for_receiver",
                "gps_for_tag_project",
                "gps_for_receiver",
                "metadata_for_tags",
                "metadata_for_receivers",
                "tags_for_ambiguities",
                "project_ambiguities_for_tag_project",
                "size_of_update_for_tag_project",
                "size_of_update_for_receiver",
                "pulse_counts_for_receiver",
                ## and these administrative (local-use-only) apps, not reverse proxied
                ## from the internet at large
                "_shutdown"
                )

#' return information about the api
#'
#' @return a list with these items:
#'    \itemize{
#'       \item maxRows; integer maximum number of rows returned by other API calls
#'    }

api_info = function(env) {

    if (tracing)
        browser()

    return_from_app(
        list(
            maxRows = MAX_ROWS_PER_REQUEST
        )
    )
}

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

    rv = NULL

    tryCatch({
        json = parent.frame()$postBody["json"]
        ## for debugging only; log username and password
        ## cat(format(Sys.time(), "%Y-%m-%dT%H-%M-%S"), ": authenticate_user: ", json, '\n', sep="", file=stderr())
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

            ## First, grab a list of ambiguous projects that this user
            ## gets access to by virtue of having access to real projects involved in them.

            realProjIDs = as.integer(names(resp$projects))
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
            projectIDs = c(realProjIDs, ambigProjIDs)
            rv = list(
                authToken = unclass(RCurl::base64(readBin("/dev/urandom", raw(), n=ceiling(OPT_TOKEN_BITS / 8)))),
                expiry = as.numeric(Sys.time()) + OPT_AUTH_LIFE,
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
        },
        error = function(e) {
            rv <<- list(error=paste("query to main motus server failed"))
        })
    }
    return_from_app(rv)
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

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    serno = json$serno %>% as.character

    if (length(serno) == 0 || ! all(grepl(MOTUS_RECV_SERNO_REGEX, serno)))
        return(error_from_app("invalid parameter(s)"))

    ## get deviceIDs for all receivers

    MetaDB("create temporary table if not exists tempSernos (serno text)")
    MetaDB("delete from tempSernos")
    dbWriteTable(MetaDB$con, "tempSernos", data.frame(serno=serno), append=TRUE, row.names=FALSE)

    query = sprintf("
select distinct
    t1.serno,
    t2.deviceID
from
   tempSernos as t1
   left join recvDeps as t2 on t1.serno=t2.serno
", paste(auth$projects, collapse=","))

    rv = MetaDB(query)

    missing = which(is.na(rv$deviceID))

    ## try lookup deviceIDs directly from receiver databases.

    if (length(missing)) {
        for (i in missing) {
            src = getRecvSrc(rv$serno[i], create=FALSE)
            if (! is.null(src)) {
                deviceID = dbGetQuery(src$con, "select val from meta where key='deviceID'")[[1]]
                rm(src) ## force closing of db connection
                if (length(deviceID))
                    rv$deviceID[i] = as.numeric(deviceID)
            }
        }
    }
    return_from_app(rv)
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

    if (tracing)
        browser()

    auth = validate_request(json)
    if (inherits(auth, "error")) return(auth)

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
    return_from_app(recvDeps)
}


#' get batches for a tag project
#'
#' @param projectID integer project ID
#' @param batchID integer batchID; only batches with larger batchID are returned
#' @param includeTesting boolean; default: FALSE.  If TRUE, and the user is an administrator,
#' then records for batches marked as `testing` are returned as if they were normal batches.
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_tag_project = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])
    if (tracing)
        browser()

    auth = validate_request(json)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    if (!isTRUE(is.finite(batchID)))
        batchID = 0

    includeTesting = (json$includeTesting %>% as.logical)[1]
    minBatchStatus = if (isTRUE(includeTesting) && isTRUE(auth$isAdmin)) -1 else 1

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
   projBatch as t2
   join batches as t1
   on t2.tagDepProjectID=%d
   and t2.batchID > %d
   and t1.batchID = t2.batchID
   and t1.status >= %d
order by
   t2.batchID
limit %d
",
auth$projectID, batchID, minBatchStatus, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
}


#' get batches for a receiver
#'
#' @param deviceID integer device ID
#' @param batchID integer batchID; only batches with larger batchID are returned
#' @param includeTesting boolean; default: FALSE.  If TRUE, and the user is an administrator,
#' then records for batches marked as `testing` are returned as if they were normal batches.
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_receiver = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    deviceID = (json$deviceID %>% as.integer)[1]
    if (!isTRUE(is.finite(deviceID))) {
        return(error_from_app("invalid parameter(s)"))
    }

    batchID = (json$batchID %>% as.integer)[1]
    if (!isTRUE(is.finite(batchID)))
        batchID = 0

    includeTesting = (json$includeTesting %>% as.logical)[1]
    minBatchStatus = if (isTRUE(includeTesting) && isTRUE(auth$isAdmin)) -1 else 1

    ## Create an ownership clause so that only batches to which the user has
    ## permission are returned.  For admin users, ownership (or lack thereof)
    ## is ignored.

    if (!isTRUE(auth$isAdmin)) {
        ownership = sprintf(" and t1.recvDepProjectID in (%s) ", paste(auth$projects, collapse=","))
    } else {
        ownership = ""
    }

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
   %s
   and t1.status >= %d
order by
   t1.batchID
limit %d
",
batchID, deviceID, ownership, minBatchStatus, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
}

#' get batches for any receiver
#'
#' @param batchID integer batch ID of largest batch already obtained
#' @param includeTesting boolean; default: FALSE.  If TRUE, and the user is an administrator,
#' then records for batches marked as `testing` are returned as if they were normal batches.
#'
#' @return a data frame with the same schema as the batches table, but JSON-encoded as a list of columns

batches_for_all = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID = FALSE, needAdmin = TRUE)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    if (!isTRUE(is.finite(batchID)))
        batchID = 0

    includeTesting = (json$includeTesting %>% as.logical)[1]
    minBatchStatus = if (isTRUE(includeTesting) && isTRUE(auth$isAdmin)) -1 else 1

    ## select batches larger than the one specified

    query = sprintf("
select
   batchID,
   motusDeviceID,
   monoBN,
   tsStart,
   tsEnd,
   numHits,
   ts,
   motusUserID,
   motusProjectID,
   motusJobID
from
   batches
where
   batchID > %d
   and status >= %d
order by
   batchID
limit %d
",
batchID, minBatchStatus, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
}

#' get runs by tag project from a batch
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param runID double ID of largest run already obtained
#'
#' @return a data frame with the same schema as the runs table, but JSON-encoded as a list of columns

runs_for_tag_project = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    runID = (json$runID %>% as.double)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(runID))) {
        return(error_from_app("invalid parameter(s)"))
    }

    ## get all runs of a tag within a deployment of that tag by the
    ## given project that overlap the given batch

    query = sprintf("
select
   cast(t1.runID as double) as runID,
   t1.batchIDbegin,
   t1.tsBegin,
   t1.tsEnd,
   t1.done,
   t1.motusTagID,
   t1.ant,
   t1.len
from
   batchRuns as t2
   join runs as t1 on t2.runID=t1.runID
where
   t2.tagDepProjectID = %d
   and t2.batchID = %d
   and t2.runID > %f
order by
   t2.runID
limit 10000
",
auth$projectID, batchID, runID, auth$projectID, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
}

#' get all runs from a batch for a receiver
#'
#' @param batchID integer batchID
#' @param runID double ID of largest run already obtained
#'
#' @return a data frame with the same schema as the runs table, but JSON-encoded as a list of columns

runs_for_receiver = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    runID = (json$runID %>% as.double)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(runID))) {
        return(error_from_app("invalid parameter(s)"))
    }

    ## Create an ownership clause so that only batches to which the user has
    ## permission are returned.  For admin users, ownership (or lack thereof)
    ## is ignored.

    if (!isTRUE(auth$isAdmin)) {
        ownership = sprintf(" and t2.recvDepProjectID in (%s) ", paste(auth$projects, collapse=","))
    } else {
        ownership = ""
    }

    ## pull out appropriate runs

    query = sprintf("
select
   cast(t1.runID as double) as runID,
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
   t1.runID > %f
   and t2.batchID = %d
   %s
order by
   t1.runID
limit %d
",
runID, batchID, ownership, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
}

#' get hits by tag project from a batch
#'
#' @param projectID integer project ID
#' @param batchID integer batchID
#' @param hitID double ID of largest hit already obtained
#'
#' @return a data frame with the same schema as the hits table, but JSON-encoded as a list of columns

hits_for_tag_project = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    hitID = (json$hitID %>% as.double)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(hitID))) {
        return(error_from_app("invalid parameter(s)"))
    }

    ## pull out appropriate hits

    query = sprintf("
select
   cast(hitID as double) as hitID,
   cast(runID as double) as runID,
   batchID,
   ts,
   sig,
   sigSD,
   noise,
   freq,
   freqSD,
   slop,
   burstSlop
from
   hits
where
   tagDepProjectID = %d
   and batchID = %d
   and hitID > %f
order by
   hitID
limit %d
",
auth$projectID, batchID, hitID, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
}

#' get all hits from a batch for a receiver
#'
#' @param batchID integer batchID
#' @param hitID double ID of largest hit already obtained
#'
#' @return a data frame with the same schema as the hits table, but JSON-encoded as a list of columns

hits_for_receiver = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    hitID = (json$hitID %>% as.double)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(hitID))) {
        return(error_from_app("invalid parameter(s)"))
    }

    ## Create an ownership clause so that only batches to which the user has
    ## permission are returned.  For admin users, ownership (or lack thereof)
    ## is ignored.

    if (!isTRUE(auth$isAdmin)) {
        ownership = sprintf(" and t2.recvDepProjectID in (%s) ", paste(auth$projects, collapse=","))
    } else {
        ownership = ""
    }

    ## pull out appropriate hits

    query = sprintf("
select
   cast(t1.hitID as double) as hitID,
   cast(t1.runID as double) as runID,
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
   t1.hitID > %f
   and t1.batchID = %d
   %s
order by
   t1.hitID
limit %d
",
hitID, batchID, ownership, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
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

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    ts = (json$ts %>% as.numeric)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(ts))) {
        return(error_from_app("invalid parameter(s)"))
    }

    ## pull out appropriate gps records we look for the first and last
    ## tag detection for the project in this batch to get the maximal
    ## timestamp for that project in the batch, add a 1-hour buffer to
    ## each end, then pull out gps fixes for that period, further
    ## limited by minimum timestamp

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
   join
      (select
         min(t3.ts) as tsBegin,
         max(t3.ts) as tsEnd
      from
         (select t2.ts from
            hits as t2
         join
            (select
                min(t5.hitID) as hitIDlo,
                max(t5.hitID) as hitIDhi
             from
                hits as t5
             where
                t5.tagDepProjectID = %d
                and t5.batchID = %d
             ) as t6
          on t2.hitID in (hitIDlo, hitIDhi)
          ) as t3
    ) as t4
where
   t1.batchID = %d
   and t1.ts > %16.4f
   and t1.ts >= t4.tsBegin - 3600
   and t1.ts <= t4.tsEnd + 3600
order by
   t1.ts
limit %d
",
auth$projectID, batchID, batchID, ts, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
}

#' get all GPS fixes from a batch
#'
#' @param batchID integer batchID
#' @param ts numeric timestamp of latest fix already obtained
#'
#' @return a data frame with the same schema as the gps table, but JSON-encoded as a list of columns

gps_for_receiver = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    ts = (json$ts %>% as.numeric)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(ts))) {
        return(error_from_app("invalid parameter(s)"))
    }

    ## Create an ownership clause so that only batches to which the user has
    ## permission are returned.  For admin users, ownership (or lack thereof)
    ## is ignored.

    if (!isTRUE(auth$isAdmin)) {
        ownership = sprintf(" and t2.recvDepProjectID in (%s) ", paste(auth$projects, collapse=","))
    } else {
        ownership = ""
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
   %s
   and t1.ts > %f
order by
   t1.ts
limit %d
",
batchID, ownership, ts, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
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

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    motusTagIDs = json$motusTagIDs %>% as.integer

    if (!isTRUE(all(is.finite(motusTagIDs)))) {
        return(error_from_app("invalid parameter(s)"))
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
    return_from_app(list(tags=tags, tagDeps=tagDeps, species=species, projs=projs))
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

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    deviceIDs = json$deviceIDs %>% as.integer

    if (!isTRUE(all(is.finite(deviceIDs)))) {
        return(error_from_app("invalid parameter(s)"))
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
    return_from_app(list(recvDeps=recvDeps, antDeps=antDeps, projs=projs))
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
#'    \item ambigProjectID; negative integer ambiguous project ID
#' }

tags_for_ambiguities = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    ambigIDs = json$ambigIDs %>% as.integer

    if (!isTRUE(all(is.finite(ambigIDs)) && all(ambigIDs < 0)) && length(ambigIDs) > 0) {
        return(error_from_app("invalid parameter(s)"))
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
   t1.motusTagID6,
   t1.ambigProjectID
from
   tagAmbig as t1
where
   t1.ambigID in (%s)
order by
   t1.ambigID desc
", paste(ambigIDs, collapse=","))

    return_from_app(MotusDB(query))
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
#' \item numBytes
#' }
#' @details the value of numHits and so numBytes is an overestimate, because
#' it counts the full length of each run, rather than just of those hits
#' added by new batches to existing runs.

size_of_update_for_tag_project = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json)
    if (inherits(auth, "error")) return(auth)

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
           runs as t2
           join batches as t3 on t2.batchIDbegin = t3.batchID
        where
           batchIDbegin > %d
           and tagDepProjectID = %d
           and t3.tsMotus >= 0
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

    return_from_app(unclass(rv))
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

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    deviceID = json$deviceID %>% as.integer
    if (!isTRUE(is.finite(deviceID)))
        return(error_from_app("invalid deviceID"))

    batchID = json$batchID %>% as.integer
    if (!isTRUE(is.finite(batchID)))
        batchID = 0

    ## Create an ownership clause so that only batches to which the user has
    ## permission are returned.  For admin users, ownership (or lack thereof)
    ## is ignored.

    if (!isTRUE(auth$isAdmin)) {
        ownership = sprintf(" and t1.recvDepProjectID in (%s) ", paste(auth$projects, collapse=","))
    } else {
        ownership = ""
    }

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
          %s
          and t1.tsMotus >= 0
       group by t1.batchID
    ) as t3
",
batchID, deviceID, ownership)
    rv = MotusDB(query)

    rv$numBytes = with(rv,
        110 + 90 * numBatches +
        75 + 64 * numRuns +
        80 + 100 * numHits +
        50 + 52 * numGPS)

    return_from_app(unclass(rv))
}

#' get project ambiguity groups for a given project
#'
#' @param projectID integer scalar project ID
#'
#' @return a list with these vector items:
#' \itemize{
#'    \item ambigProjectID; negative integer project ambiguity ID
#'    \item projectID1; positive integer motus project ID
#'    \item projectID2; positive integer motus project ID
#'    \item projectID3; positive integer motus project ID or null
#'    \item projectID4; positive integer motus project ID or null
#'    \item projectID5; positive integer motus project ID or null
#'    \item projectID6; positive integer motus project ID or null
#' }

project_ambiguities_for_tag_project = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json)
    if (inherits(auth, "error")) return(auth)

    query = sprintf("
select
   ambigProjectID,
   projectID1,
   projectID2,
   projectID3,
   projectID4,
   projectID5,
   projectID6
from
   projAmbig
where
   %d in (projectID1, projectID2, projectID3, projectID4, projectID5, projectID6)
order by
   ambigProjectID desc
", auth$projectID)

    return_from_app(MotusDB(query))
}

#' get pulse counts from a batch
#'
#' @param batchID integer batchID
#' @param ant integer
#' @param hourBin numeric hourBin of latest pulseCounts already obtained
#'
#' The pair (ant, hourBin) is for the latest record already obtained.
#' For each \code{batchID}, records are returned sorted by
#' \code{hourBin} within \code{ant}.  For the first call with each \code{batchID},
#' the caller should specify \code{hourBin=0}, in which case \code{ant} is ignored.
#'
#' @return a data frame with the same schema as the pulseCounts table, but
#'     JSON-encoded as a list of columns

pulse_counts_for_receiver = function(env) {

    json = fromJSON(parent.frame()$postBody["json"])

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    batchID = (json$batchID %>% as.integer)[1]
    hourBin = (json$hourBin %>% as.numeric)[1]
    ant = (json$ant %>% as.integer)[1]

    if (!isTRUE(is.finite(batchID) && is.finite(hourBin) && is.finite(ant))) {
        return(error_from_app("invalid parameter(s)"))
    }

    if (hourBin == 0)
        ## for first call on this batch, set antenna to a value smaller than
        ## any real antenna
        ant = -32767

    ## Create an ownership clause so that only batches to which the user has
    ## permission are returned.  For admin users, ownership (or lack thereof)
    ## is ignored.

    if (!isTRUE(auth$isAdmin)) {
        ownership = sprintf(" and t2.recvDepProjectID in (%s) ", paste(auth$projects, collapse=","))
    } else {
        ownership = ""
    }

    ## pull pulse count records provided the batch is for a deployment of the
    ## receiver by one of the projects the user is authorized for

    query = sprintf("
select
    t1.batchID,
    t1.ant,
    t1.hourBin,
    t1.count
from
   pulseCounts as t1
   join batches as t2 on t2.batchID=t1.batchID
where
   t2.batchID = %d
   %s
   and t1.ant > %d
   and t1.hourBin > %f
order by
   t1.ant,
   t1.hourBin
limit %d
",
batchID, ownership, ant, hourBin, MAX_ROWS_PER_REQUEST)
    return_from_app(MotusDB(query))
}


#' shut down this server.  The leading '_', which requires the appname to be
#' quoted, marks this as an app that won't be exposed to the internet via
#' the apache reverse proxy

`_shutdown` = function(env) {
    on.exit(q(save="no"))
    error_from_app("data server shutting down")
}
