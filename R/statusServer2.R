#' reply to http requests for information on the processing queue; API version
#'
#' @param port integer; local port on which to listen for requests;
#' default: 0x57A7
#'
#' @param tracing logical; if TRUE, run interactively, allowing local user
#' to enter commands.
#'
#' @param maxRows integer; maximum number of rows to return per request.
#' Default: 20
#'
#' @return does not return; meant to be run as a server.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

statusServer2 = function(port = 0x57A7, tracing=FALSE, maxRows=20L) {

    serverCommon()

    ## save maxRows in a global variable so methods can obtain it
    MAX_ROWS_PER_REQUEST <<- maxRows

    loadJobs()

    ## ensure a large cache - we use the server DB intensively
    ServerDB("pragma cache_size=60000")

    ## save server in a global variable in case we are tracing

    SERVER <<- Rhttpd$new()

    tracing <<- tracing

    ## add each function below as an app

    for (f in allStatusApps)
        SERVER$add(RhttpdApp$new(app = get(f), name = f))

    motusLog("Status server (API version) started")

    SERVER$start(port = port)

    if (! tracing) {
        ## sleep while awaiting requests
        suspend_console()
    }
}

## a string giving the list of apps for this server
## Note that we re-use authenticate_user from dataServer.R

allStatusApps = c("status_api_info", "list_jobs", "_shutdown", "authenticate_user", "process_new_upload", "list_receiver_files", "get_receiver_info", "get_job_stackdump")

sortColumns = c("ctime", "mtime", "id", "type", "motusProjectID", "motusUserID")

#' add condition(s) to the where clause; strip
#' any leading "where " from the items in clauses,
#' then join them together using conj and add a preceding "where "
makeWhere = function(clauses, conj="and", prep="where") {
    if (length(clauses) == 0)
        return("")
    clauses = sub(paste0("^", prep, " "), "", clauses, ignore.case=TRUE)
    return(paste0(prep, " ", paste0("(", clauses, ")", collapse = conj)))
}

#' add condition(s) to the order by clause
#' @param order existing order clause
#' @param new new order by field; either "FIELD" or "FIELD desc"
#' @param desc logical; descending order?
#' @param toggle says whether to toggle descending/ascending order

addToOrder = function(order, new, desc, toggle) {
    for (n in new) {
        new = paste0(new, ifelse(xor(desc, toggle), " desc", ""))
        if (order == "")
            order = paste0("order by ", new)
        else
            order = paste0(order, ", ", new)
    }
    return(order)
}

#' return information about the status api
#'
#' @return a list with these items:
#'    \itemize{
#'       \item maxRows; integer maximum number of rows returned by other API calls
#'    }

status_api_info = function(env) {

    if (tracing)
        browser()

    return_from_app(
        list(
            maxRows = MAX_ROWS_PER_REQUEST,
            uploadPath = file.path("sgdata", MOTUS_PATH$UPLOADS_PARTIAL) ## "sgdata" is a folder on the NAS itself
        )
    )
}

#' return a list of jobs, sorted by user-selected criteria

list_jobs = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    projectID = auth$projectID

    select  = json$select
    order   = json$order
    options = json$options

    ## selectors
    userID    = safe_arg(select, userID, int)
    selProjectID = safe_arg(select, projectID, int)
    jobID     = safe_arg(select, jobID, int, scalar=FALSE)
    stump     = safe_arg(select, stump, int)
    type      = safe_arg(select, type, char, scalar=FALSE)
    done      = safe_arg(select, done, int)
    log       = safe_arg(select, log, char)

    ## ordering
    sortBy = safe_arg(order, sortBy, char)
    sortDesc = isTRUE(safe_arg(order, sortDesc, logical))
    lastKey = safe_arg(order, lastKey, list, scalar=FALSE)
    if (sortBy != "type" && length(lastKey) > 0) {
        lastKey[[1]] = as.numeric(lastKey[[1]])
    }
    forwardFromKey = safe_arg(order, forwardFromKey, logical)

    ## options
    includeUnknownProjects = isTRUE(safe_arg(options, includeUnknownProjects, logical))
    countOnly              = isTRUE(safe_arg(options, countOnly, logical))
    full                   = isTRUE(safe_arg(options, full, logical))
    includeSubjobs         = isTRUE(safe_arg(options, includeSubjobs, logical))
    errorOnly              = isTRUE(safe_arg(options, errorOnly, logical))
    maxRows                = safe_arg(select, maxRows, int)
    if (is.null(maxRows))
        maxRows = MAX_ROWS_PER_REQUEST

    ## validate access

    if (is.null(projectID))
        projectID = auth$projects
    if (! is.null(selProjectID)) {
        if (! selProjectID %in% projectID)
            return(error_from_app("not authorized for that project"))
        projectID = selProjectID
    }
    if (! (is.null(userID) || userID == auth$userID || auth$userType == "administrator")) {
        return(error_from_app("not authorized for that userID"))
    }

    ## generate where clause from selectors

    if (includeSubjobs)
        where = NULL
    else
        where = makeWhere("t1.pid is null")  ## only top-level jobs; these have no parent id
    if (is.null(projectID)) {
        projwhere = NULL
    } else {
        projwhere = sprintf("t1.motusProjectID in (%s)", paste(projectID, collapse=","))
    }
    if (isTRUE(includeUnknownProjects))
        projwhere = makeWhere(c(projwhere, "t1.motusProjectID is null"), conj="or")
    where = c(where, projwhere)
    if (!is.null(userID))
        where = c(where, sprintf("t1.motusUserID = %d", userID))
    if (!is.null(jobID))
        where = c(where, sprintf("t1.id in (%s)", paste0("'", jobID, "'", collapse=",")))
    if (!is.null(stump)) {
        ## allow for having been given a subjob's ID rather than that of the top-level job.
        stumpID = ServerDB("select stump from jobs where id=%d", stump)[[1]]
        where = c(where, sprintf("t1.stump = %d", stumpID))
    }
    if (!is.null(type))
        where = c(where, sprintf("t1.type in (%s)", paste0("'", type, "'", collapse=",")))
    if (!is.null(done))
        where = c(where, switch(as.character(done), `1` = "t1.done > 0", `0` = "t1.done = 0", `-1` = "t1.done < 0"))
    if (!is.null(log))
        where = c(where, sprintf("t1.data glob '%s'", log))

    where = makeWhere(where)
    ## generate `order by` and additional `where` clause items for paging

    if (is.null(sortBy)) {
        sortBy = "mtime"
    } else if (! sortBy %in% sortColumns) {
        return(error_from_app("invalid sortBy"))
    }

    ## `having` is only used if errorOnly is true
    having = if (isTRUE(errorOnly)) "having sjDone < 0" else ""

    ## if not the ID field, then append the ID field
    if (sortBy != "id") {
        sortBy = c(sortBy, "id")
    }

    ## prefix with "t1"
    sortBy = paste0("t1.", sortBy)

    if (! (length(lastKey) == 0 || length(lastKey) <= length(sortBy))) {
        return(error_from_app("invalid number of `lastKey` values for given `sortBy`"))
    }

    if (is.null(forwardFromKey))
        forwardFromKey = TRUE

    ## calculate extra `where` components from paging criteria
    if (! is.null(lastKey)) {
        w = NULL
        op = if (xor(sortDesc, forwardFromKey)) ">" else "<"
        ## soften constraint for fields known to have non-unique values, and for which we're not sub-paging
        ## by id
        if (length(lastKey) <= 1 && sortBy[1] != "t1.id")
            op = paste0(op, "=")
        if (sortBy[1] == "t1.type") {
            w = sprintf("%s %s '%s'", sortBy[1], op, lastKey[[1]])
        } else {
            w = sprintf("%s %s %f", sortBy[1], op, lastKey[[1]])
        }
        if (length(lastKey) > 1) {
            if (sortBy[1] == "t1.type") {
                w = paste0(w, sprintf(" or (%s = '%s' and t1.id %s %f)", sortBy[1], lastKey[[1]], op, lastKey[[2]]))
            } else {
                w = paste0(w, sprintf(" or (%s =  %f  and t1.id %s %f)", sortBy[1], lastKey[[1]], op, lastKey[[2]]))
            }
        }
        where = makeWhere(c(where, w))
    }

    order = ""
    for (i in seq(along=sortBy))
        order = addToOrder(order, sortBy[i], sortDesc, ! forwardFromKey)

    ## pull out appropriate jobs and details

    if (isTRUE(countOnly)) {

        query = sprintf("
select
   count(*)
from jobs as t1
%s",
where,
having)
    } else {
        query = sprintf("
select
   t1.id,
   t1.pid,
   t1.stump,
   t1.ctime,
   t1.mtime,
   t1.type,
   t1.done,
   t1.queue,
   t1.path,
   t1.motusUserID,
   t1.motusProjectID
   %s
   %s
from
   jobs as t1
   %s
%s
%s
%s
%s
limit %d",
if (isTRUE(full)) ", t1.data" else "",
if (isTRUE(includeSubjobs)) ", null as sjDone" else ", min(t2.done) as sjDone",
if (isTRUE(includeSubjobs)) "" else " left join jobs as t2 on t2.stump=t1.id",
where,
if (isTRUE(includeSubjobs)) "" else " group by t1.id",
having,
order,
if (is.null(stump)) maxRows else -1
)
    }
    ## if forwardFromKey was FALSE, we need to re-order results to match the
    ## desired sort order
    if (! isTRUE(forwardFromKey)) {
        order = ""
        for (i in seq(along=sortBy))
            order = addToOrder(order, sortBy[i], sortDesc, FALSE)
        query = sprintf("select * from (%s) as t1 %s", query, order)
    }
    return_from_app(ServerDB(query))
}

#' shut down this server.  The leading '_', which requires the appname to be
#' quoted, marks this as an app that won't be exposed to the internet via
#' the apache reverse proxy

`_shutdown` = function(env) {
    on.exit(q(save="no"))
    error_from_app("status server (API version) shutting down")
}

process_new_upload = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    projectID = auth$projectID
    userID = safe_arg(json, userID, int)
    if (is.null(userID))
        return(error_from_app("missing integer userID"))
    path = safe_arg(json, path, char)
    if (is.null(path))
        return(error_from_app("missing path"))
    comps = strsplit(path, '[/\\\\]', perl=TRUE)[[1]]
    if (any(comps == ".."))
        return(error_from_app("path is not allowed to contain any '/../' components"))
    if (grepl('"', path, fixed=TRUE))
        return(error_from_app("path is not allowed to contain any '\"' characters"))
    realpath = paste0(MOTUS_PATH$UPLOADS, path)
    if (!file.exists(realpath))
        return(error_from_app(paste0("non-existent file: `NAS:/sgdata/", realpath, "`")))
    if (is.null(projectID))
        return(error_from_app("missing integer projectID"))
    ts = safe_arg(json, ts, numeric)
    if (is.null(ts)) {
        ## try again, this time assuming it's a ymd_hms-compatible string in GMT
        ts = safe_arg(json, ts, character)
        if (!is.null(ts)) {
            ts = as.numeric(ymd_hms(ts))
        }
        if (!isTRUE(ts > 0)) {
            ts = as.numeric(Sys.time())
        }
    }

    ## see whether we already have this file (by content digest)
    digest = digestFile(realpath)
    have = MotusDB("select * from uploads where sha1=%s", digest)
    if (nrow(have))
        return(error_from_app("refusing to process file - it was already uploaded; see details; please contact motus.org, quoting this message, to have this file reprocessed",
                              details = unclass(have)))
    ## move file and change ownership.  It will now have owner:group = "sg:sg" and
    ## permissions "rw-rw-r--"
    newPath = file.path(MOTUS_PATH$UPLOADS, userID, basename(realpath))
    safeSys("mv", realpath, newPath)
    safeSys("sudo", "chown", "sg:sg", newPath)
    safeSys("sudo", "chmod", "u=rw,g=rw,o=r", newPath)

    ## for debugging, if file "/sgm/UPLOAD_TESTING"" exists, give this new job
    ## an `isTesting=TRUE` parameter, so that its product batches end up marked
    ## that way in the master DB.  Its products will also go to the /sgm/testing
    ## hierarchy instead of /sgm/www.  To avoid having the flag show up in
    ## the status display, we only set its value when TRUE.

    isTesting = if (file.exists(MOTUS_PATH$UPLOAD_TESTING)) TRUE else NULL

    ## create and enqueue a new upload job
    j = newJob("uploadFile",
               .parentPath = MOTUS_PATH$INCOMING,
               motusUserID = userID,
               motusProjectID = projectID,
               isTesting = isTesting,
               filename = newPath,
               .enqueue=FALSE)

    jobID = unclass(j)

    ## insert into uploads table
    MotusDB("insert into uploads (jobID, motusUserID, motusProjectID, filename, sha1, ts) values (%d, %d, %d, %s, %s, %f)",
            jobID, userID, projectID, path, digest, ts)

    uploadID = MotusDB("select LAST_INSERT_ID()")[[1]]
    j$uploadID = uploadID

    ## get file basename
    bname = basename(newPath)

    ## record receipt within the job's log
    jobLog(j, paste("File uploaded:", bname), summary=TRUE)

    jpath = file.path(jobPath(j), "upload")
    dir.create(jpath)
    ## symlink to uploaded file from the job's dir
    ## We symlink because:
    ## - we want to maintain the original file unmodified
    ## - the file can be on a different filesystem than the
    ##   jobs hierarchy

    file.symlink(newPath, file.path(jpath, bname))

    ## move the job to the main queue

    j$queue = "0"
    moveJob(j, MOTUS_PATH$QUEUE0)

    cat("Job", jobID, "has been entered into queue 0\n")

    return_from_app(list(jobID = jobID, uploadID = uploadID, newPath = newPath))
}

#' return a dplyr::tbl of files from a receiver database
#' @param serno character scalar receiver serial number
#' @param day character scalar day; default NULL
#' @return a tbl; one of two flavours, depending on
#' the receiver type and `day`.
#'
#' If the receiver is a sensorgnome and day is \code{NULL}, the return value has
#' these columns sorted by decreasing day:
#' \itemize{
#' \item day: character; day, formatted as "YYYY-MM-DD"
#' \item count: integer; number of files from the day in the receiver DB `files` table.
#' }
#' For a Lotek receiver, \code{count} is always 1, and each row simply indicates that the
#' receiver recorded at least one detection that day.  As for sensorgnomes, this
#' flavour of return value is meant to indicate whether the receiver was operating
#' that day.
#'
#' Otherwise, if `day` is given, the return value has these columns,
#' sorted by fileID:
#' \itemize{
#'   \item fileID: integer; ID of file
#'   \item name: character; name of file
#'   \item bootnum: integer; boot count, uncorrected; if an SG file
#'   \item monoBN: integer; corrected boot count; if an SG file
#'   \item contentSize: integer; uncompressed file size in bytes
#'   \item jobID: the integer motus ID for the job in which this file was most recently updated
#' }
#' For Lotek receivers, this will be a list of all data files; for sensorgnomes,
#' this will only include files from the given day.

files_from_recv_DB = function (serno, day=NULL) {
    isSG = getRecvType(serno) == "SENSORGNOME"
    sql = safeSQL(getRecvSrc(serno))
    if (isSG) {
        if (is.null(day)) {
            rv = sql('select day, count(*) as count from (select fileID, strftime("%Y-%m-%d", datetime(ts, "unixepoch")) as day from files) as j group by j.day order by j.day desc')
        } else {
            tsRange = c(0, 24*3600) + as.numeric(ymd_hms(paste(day, "00:00:00")))
            rv = sql("select fileID, name, bootnum, monoBN, size as contentSize, motusJobID as jobID from files where ts between :dayStart and :dayEnd order by fileID", dayStart=tsRange[1], dayEnd=tsRange[2])
        }
    } else {
        if (is.null(day)) {
            rv = sql("select strftime('%Y-%m-%d', datetime(day, 'unixepoch')) as day, 1 as count from (select distinct 24*3600*round(ts/(24*3600)) as day from DTAtags where ts is not null order by ts)")
        } else {
            rv = sql("select fileID, name, null as bootnum, null as monoBN, size, motusJobID as jobID from DTAfiles order by fileID")
        }
    }
    return(as.tbl(rv))
}

#' return a dplyr::tbl of files from the file repository
#' for a receiver (and maybe specific day)
#'
#' @param serno character scalar receiver serial number
#' @param day character scalar day; default NULL
#' @return a tbl; one of two flavours, depending on
#' the receiver type and `day`.
#'
#' If the receiver is a sensorgnome and day is \code{NULL}, the return value has
#' these columns sorted by decreasing day:
#' \itemize{
#' \item day: character; day, formatted as "YYYY-MM-DD"; any days for which the repo has files
#' \item count: integer; number of files from the day in the file repo
#' }
#'
#' Otherwise, for Lotek receivers or if `day` is given, the return value has these columns,
#' sorted by fileID:
#' \itemize{
#'   \item name: character; name of file
#'   \item fileSize: integer; size of file on disk, in bytes
#' }
#' For Lotek receivers, day is ignored (as long as it is present), and all files for the
#' receiver are listed.
#'
#' @note for SG receivers, when both a compressed and un uncompressed version of the file
#' are present, this only counts as one file, and if returning files, the name is returned
#' without a ".gz" suffix, but the size is of the .gz file on disk

files_from_repo = function (serno, day=NULL) {
    isSG = getRecvType(serno) == "SENSORGNOME"
    repo = file.path(MOTUS_PATH$FILE_REPO, serno)
    if (isSG) {
        if (is.null(day)) {
            ## count only one of "XXX.txt.gz", "XXX.txt"
            counts = sapply(dir(repo), function(day) sum(!duplicated(sub("\\.gz$", "", dir(file.path(repo, day))))))
            rv = data.frame(day = I(names(counts)), count = as.integer(counts))
        } else {
            repo = file.path(repo, day)
            files = dir(repo, full.names=TRUE)
            ## for a pair ("XXX.txt.gz", "XXX.txt"), return "XXX.txt" as the name, but the size
            ## for file "XXX.txt.gz"
            bareNames = sub("\\.gz$", "", basename(files))
            dup = duplicated(bareNames)
            dupRev = duplicated(bareNames, fromLast=TRUE)
            rv = data.frame(name=I(bareNames[!dup]), fileSize=file.size(files)[!dupRev])
        }
    } else {
        files = dir(repo, full.names=TRUE)
        rv = data.frame(name=I(basename(files)), fileSize=file.size(files))
    }
    return(as.tbl(rv))
}

SERNO_REGEX = paste0('^((', motusServer:::MOTUS_SG_SERNO_REGEX, ')|(', 'Lotek-D?[0-9]+))$')
DAY_REGEX = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

#' return a list of files for a receiver

list_receiver_files = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    ## parameters
    serno     = safe_arg(json, serno, char)
    day       = safe_arg(json, day, char)

    ## validate

    if (is.null(serno))
        return(error_from_app("must specify receiver serial number (`serno`)"))

    if (!grepl(SERNO_REGEX, serno, perl=TRUE))
        return(error_from_app("invalid receiver serial number (`serno`)"))

    if (!any(file.exists(c(file.path(MOTUS_PATH$FILE_REPO, serno), file.path(MOTUS_PATH$RECV, paste0(serno, ".motus"))))))
        return(error_from_app("unknown receiver"))

    isSG = getRecvType(serno) == "SENSORGNOME"

    rv = list(serno=serno)

    if (is.null(day)) {
        db = files_from_recv_DB(serno)
        if (isSG) {
            fs = files_from_repo(serno)
            fc = db %>% full_join(fs, by="day") %>% arrange(desc(day)) %>% as.data.frame
        } else {
            fc = db %>% mutate(countFS=1) %>% as.data.frame
        }
        names(fc) = c("day", "countDB", "countFS")
        fc$countDB[is.na(fc$countDB)] = 0
        fc$countFS[is.na(fc$countFS)] = 0
        if (nrow(fc) > 0)
            rv$fileCounts = fc
        else
            rv$fileCounts = NULL
    } else {
        if (! grepl(DAY_REGEX, day, perl=TRUE))
            return(error_from_app("invalid day"))
        rv$day = day
        fs = files_from_repo(serno, day)
        db = files_from_recv_DB(serno, day)
        rv$fileDetails = db %>% full_join(fs, by="name") %>% arrange(fileID) %>% as.data.frame
    }
    return_from_app(rv)
}


#' return a list of files for a receiver

get_receiver_info = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    ## parameters
    serno = safe_arg(json, serno, char)

    ## validate

    if (is.null(serno))
        return(error_from_app("must specify receiver serial number (`serno`)"))

    if (!grepl(SERNO_REGEX, serno, perl=TRUE))
        return(error_from_app("invalid receiver serial number (`serno`)"))

    rv = list(serno=serno, receiverType=getRecvType(serno))

    deps = MetaDB("select * from recvDeps where serno=:serno order by tsStart desc", serno=serno)

    ## extract items which are the same in every row
    rv$deviceID = deps$deviceID[1]
    ## drop no-longer-needed fields
    deps[c("deviceID", "receiverType", "id")] = NULL

    rv$deployments = deps
    return_from_app(rv)
}


#' return a URL to an .rds file stack dump for a job with errors

get_job_stackdump = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    jobID = safe_arg(json, jobID, int, scalar=FALSE)

    done = ServerDB("select done from jobs where id=%d", jobID)[[1]]
    if (length(done) == 0)
        return(error_from_app("non-existent job"))
    if (! isTRUE(done < 0))
        return(error_from_app("job did not have an error"))
    dumpfile = file.path(MOTUS_PATH$WWW, "errors", sprintf("%08d.rds", jobID))
    if (! file.exists(dumpfile))
        return(error_from_app("no stack dump available for job"))
    return_from_app(list(jobID = jobID, URL = getDownloadURL(errorJobID = jobID), size=file.size(dumpfile), path=dumpfile))
}

queueStatusApp = function(env) {
    ## return summary of master queue and processing queues
    ## parameters:
    ## - none so far

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "text/html; charset=utf-8")
    ## is upload server running?
    us = file.exists("/sgm/uploadServer.pid")

    ## number of upload jobs waiting, started, completed successfully, completed with error
    uinfo = ServerDB("select count(*) from jobs where type = 'uploadFile' and queue == '0'
            union all select count(*) from jobs where type = 'uploadFile' and queue != '0'
            union all select count(*) from jobs where type = 'uploadProcessed' and done>0
            union all select count(*) from jobs where type = 'uploadProcessed' and done<0")[[1]]

    ## number of embargoed emails awaiting processing
    emb = length(dir("/sgm/inbox_embargoed"))

    ## number of emails in inbox, awaiting processing
    inb = length(dir("/sgm/inbox"))

    ## is emailServer running?
    es = file.exists("/sgm/emailServer.pid")

    ## num jobs in email queue
    qm = ServerDB("select count(distinct t1.id) from jobs as t1 join jobs as t2 on t1.id=t2.stump where t1.pid is null and t1.queue='E' and t2.done=0")[[1]]

    ## num jobs waiting to be assigned to a processor
    q0 = ServerDB("select count(*) from jobs where pid is null and queue='0' and done=0")[[1]]

    ## which processServers, if any, are running
    pids = dir("/sgm", pattern="^processServer[0-9]+.pid$", full.names=TRUE)
    if (length(pids) > 0)
        qr = as.integer(unlist(regexPieces("processServer(?<qn>[0-9]+).pid", pids)))
    else
        qr = integer(0)

    ul = "---------------------------------------------\n"
    res$write(paste0(
        "<small>As of ", format(Sys.time(), "%d %b %Y %H:%M:%S (GMT)</small>"),
        "<pre>",
        "<b>Upload Server</b>\n",
        " - ", if (! us) "<b>not</b> ", "running\n",
        " - files received by upload: ", uinfo[1]+uinfo[2], "\n",
        " - files waiting for a processor: ", uinfo[1], "\n",
        " - files with processing completed successfully: ", uinfo[3], "\n",
        " - files where processing stopped with an error: ", uinfo[4], "\n",
        ul,
        "<b>Embargoed INBOX</b>\n",
        emb, " email(s) awaiting manual intervention\n",
        ul,
        "<b>INBOX</b>\n",
        inb, " email(s) awaiting Email Server\n",
        ul,
        "<b>Email Server</b>\n",
        " - ", if (! es) "<b>not</b> ", "running\n",
        " - has ", qm, " email(s) partially processed\n",
        ul,
        "<b>Master Queue</b>\n",
        q0, " jobs waiting for a Tagfinder Processor\n"
        ))

    ## for each tagfinder process, show its status and queue length

    for (p in c(1:8, 101:104)) {
        pc = as.character(p)
        running = p %in% qr
        jj = ServerDB("select distinct t1.id from jobs as t1 join jobs as t2 on t1.id = t2.stump where t1.pid is null and t1.queue=:p and t2.done=0", p=pc)[[1]]
        jdone = ServerDB("select count(*) from jobs as t1 where t1.pid is null and t1.queue=:p and t1.done!=0", p=pc)[[1]]
        jbad = ServerDB("select count(distinct t1.id) from jobs as t1 join jobs as t2 on t1.id = t2.stump where t1.pid is null and t1.queue=:p and t2.done<0", p=pc)[[1]]
        res$write(paste0(ul,
          "<b>Tagfinder Processor #", p, ifelse(p > 100, " (priority) ", ""), "</b>\n",
          " - ", if (! running) "<b>not</b> ", "running\n",
          "<b>Jobs:</b>\n",
          " - successfully completed: ", jdone - jbad, "\n",
          " - completed with error(s): ", jbad, "\n",
          " - incomplete: ", length(jj), "\n"
          ))
        if (length(jj) > 0) {
            res$write("<b>Incomplete jobs:</b>")
            info = ServerDB("select t1.id, coalesce(json_extract(t1.data, '$.replyTo[0]'), json_extract(t1.data, '$.replyTo')), t1.type, t1.ctime, t1.mtime, group_concat(t2.type) as sj from jobs as t1 join jobs as t2 on t1.id=t2.stump where t1.id in (:jj) and t2.done == 0 group by t1.id order by t1.id desc", jj=jj)
            class(info$ctime) = class(info$mtime) = c("POSIXt", "POSIXct")
            info$sj = sapply(info$sj, function(x) { j = strsplit(x, ",")[[1]]; t = table(j); paste(sprintf("%s(%d)", names(t), t), collapse=", ")})
            names(info) = c("ID", "Sender", "Type", "Created", "Last Activity", "Incomplete SubJobs")
            res$write(hwrite(info, border=0, row.style=list('font-weight:bold'), row.bgcolor=rep(c("#ffffff", "#f0f0f0"), length=nrow(info))))
        }
    }
    res$finish()
}

connectedReceiversApp = function(env) {

    req <- Rook::Request$new(env)
    res <- Rook::Response$new()

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "text/html; charset=utf-8")

    user <- req$GET()[['user']]
    token <- req$GET()[['token']]

    ## saveRDS(env, "/tmp/request.rds") ## for debugging

    ## list of serial numbers of connected receivers
    recv = dir(MOTUS_PATH$REMOTE_CONNECTIONS)

    ## list of mapped tunnel ports (character vector)
    ports = system("netstat -n -l -t 2>/dev/null | grep 127.0.0.1 | gawk '{split($4, A, /:/); pn=0+A[2]; if (pn >= 40000 && pn < 50000) print pn}'", intern=TRUE)

    ## get list of receiver serial numbers by port

    if (length(ports) > 0) {
        portByRecv = ServerDB(sprintf("select tunnelport,serno from remote.receivers where tunnelport in (%s)", paste(ports, collapse=",")))
        rownames(portByRecv) = portByRecv$serno
    } else {
        portByRecv = NULL
    }

    ## add in receivers with an ssh port mapped but no live data streaming
    ## this can happen for various reasons, e.g. if the master js process
    ## on the SG has died.

    connRecv = recv
    recv = unique(c(recv, portByRecv$serno))

    ## get latest project/site names for any receivers
    YEAR = format(Sys.time(), "%Y")
    ## get most recent project, site for each receiver deployment
    projSite = MetaDB(sprintf("select t1.serno as Serno, t3.label as Project, t1.name as Site, t3.id as projectID from recvDeps as t1 left join recvDeps as t2 on t1.serno=t2.serno and t1.tsStart < t2.tsStart join projs as t3 on t1.projectID=t3.id where t1.serno in ('%s') and t2.serno is null", paste0("SG-", recv, collapse="','")))

    rownames(projSite)=substring(projSite$Serno, 4)


    Now = Sys.time()
    now = as.numeric(Now)
    html = sprintf(
        "
<br>This table generated at %s
<br>
<table rows=%d cols=%d border=1>
<tr><th>Serial No.<br>Click for SG<br>Web Interface</th><th>Tunnel Port</th><th>Lat/Lon<br>Click for Map</th><th>Project, Site<br>Click for Download Page</th><th>Boot<br>Count</th><th>Connected<br>Since</th><th>Ants with Hits<br>Latest Hour</th><th>Latest Hit on Tag<br>Known to Receiver</th><th>When</th><th>Hits Today</th><th>Total Hits</th><th>Live User</th></tr>",
format(Now, "%Y %b %d %H:%M:%S GMT"),
1 + length(recv), 10)

    tbl = character(length(recv))


    con = dbConnect(SQLite(), MOTUS_PATH$REMOTE_LIVE)
    dbExecute(con, "pragma busy_timeout=300000")
    sql = function(...) dbGetQuery(con, sprintf(...))
    if (! is.null(user)) {
        old_token = sql("select token from user_tokens where user='%s'", user)

        if (nrow(old_token) == 0 || old_token[1,1] != token)
            ## auth token is new or has changed, so insert new one with timestamp
            sql("insert or replace into user_tokens (user, token, ts) values ('%s', '%s', '%f')", user, token, as.numeric(Sys.time()))
    }
    ## get the list of SG <-> user connections
    loggedIn = sql("select serno,user,ts from port_maps")
    dbDisconnect(con)
    rownames(loggedIn) = loggedIn$serno
    class(loggedIn$ts) = c("POSIXt", "POSIXct")

    for (i in seq(along=recv)) {
        db = file.path(MOTUS_PATH$REMOTE_STREAMS, paste0(recv[i], ".sqlite"))
        if (file.exists(db)) {
            cat("About to try open ", db, "\n")
            con = dbConnect(RSQLite::SQLite(), db)
            dbExecute(con, "pragma busy_timeout=300000")
            bootCount = dbGetQuery(con, "select max (parval) from metadata where parname = 'bootCount'")[1,1]
            if (is.na(bootCount))
                bootCount = 0
            gps = dbGetQuery(con, "select * from gps where ts != 'NaN' order by ts desc limit 1")
            tag = dbGetQuery(con, "select * from taghits order by ts desc limit 1")
            numHits = dbGetQuery(con, "select count(*) from taghits")
            numHitsToday = dbGetQuery(con, sprintf("select count(*) from taghits where ts >= %f", trunc(Now, "days")))
            ##        devices = dbGetQuery(con, "select * from devices order by ts")
            lastCon = dbGetQuery(con, "select serverts from connections order by serverts desc limit 1")
            ports = unlist(dbGetQuery(con, sprintf("select distinct port from taghits where serverts >= %f", now-3600))[,1])
            if (length(ports) == 0)
                ports = ""
            if (nrow(lastCon) > 0) {
                lastCon = lastCon[1,1]
            } else {
                lastCon = 0
            }
            class(lastCon) = c("POSIXt", "POSIXct")
            ## if (nrow(devices) > 0) {
            ##   numAnts = sum(unlist(tapply(seq_len(nrow(devices)), devices$port,
            ##     function(i) {
            ##       j = tail(i, 1)
            ##       devices$action[j] == 'A' && grepl("funcube", devices$type[j], ignore.case=TRUE)
            ##     })))
            ## } else {
            ##   numAnts = 0
            ## }
            dbDisconnect(con)
        } else {
            bootCount = 1
            gps = NULL
            tag = NULL
            numHits = 0
            numHitsToday = 0
            ports = ""
            lastCon = structure(0, class=c("POSIXt", "POSIXct"))
        }
        haveTags = ! (is.null(tag) || nrow(tag) == 0)

        if (haveTags) {
            class(tag$ts) = c("POSIXt", "POSIXct")
            msg = list(tag = paste(tag$tagID, "on ant", tag$port[1]),
                       ts = paste(format(round(diff(c(tag$ts[1], Now)), 3)), "ago"))
        } else {
            msg = list(tag = "none while connected", ts = "")
            numHits = numHitsToday = 0
        }

        if (is.null(gps) || nrow(gps) == 0) {
            gps = list(lat=0, lon=0)
            if (haveTags)
                tag$ts[1] = structure(tag$serverts[1], class=c("POSIXt", "POSIXct"))
        }

        tunnelport = as.character(portByRecv[recv[i], "tunnelport"])
        if (length(tunnelport) == 0 || is.na(tunnelport))
            tunnelport = "none"

        user = loggedIn[recv[i], "user"]
        if (is.na(user))
            userMsg = ""
        else
            userMsg = sprintf("%s @ %s", user, format(loggedIn[recv[i], "ts"], "%b %d - %H:%M"))

        try({
            if (tunnelport != "none") {
                anchor = sprintf('<a href="https://live.sensorgnome.org/SESSION_SG-%s_%s" style="color: #000000">%s</a>',
                                 recv[i],
                                 token,
                                 recv[i])
            } else {
                anchor = sprintf("%s", recv[i])
            }

            ps = projSite[recv[i], c("Project", "Site")]

            if (is.na(ps[[1]])) {
                ps = c("unregistered deployment")
            } else {
                ps = as.character(ps)
            }
            latLon = paste(round(gps$lat, 3), round(gps$lon, 3), sep=",")
            latLonURL = sprintf("https://google.com/search?q=%.6f,%.6f", gps$lat, gps$lon)


            psURL = getDownloadURL(projSite[recv[i], "projectID"])
            tbl[i] = sprintf('<tr><td style="background-color: %s">%s</td><td style="text-align:center">%s</td><td style="text-align:center"><a href="%s">%s</a></td><td style="text-align:center"><a href="%s">%s</a></td><td style="text-align:center">%d</td><td style="text-align:center">%s</td><td style="text-align:center">%s</td><td style="text-align:center">%s</td><td style="text-align:center">%s</td><td style="text-align:center">%.0f</td><td style="text-align:center">%.0f</td><td style="text-align:center">%s</td></tr>',
                             if (recv[i] %in% connRecv) "#80ff80" else "#ff8080",
                             anchor,
                             tunnelport,
                             latLonURL,
                             latLon,
                             psURL,
                             paste(ps, collapse=","),
                             bootCount,
                             format(lastCon, "%d %b %H:%M"),
                             paste(sort(ports), collapse=", "),
                             msg$tag,
                             msg$ts,
                             numHitsToday,
                             numHits,
                             userMsg
                             )

        }, silent=TRUE)
    }

    html = paste(html, paste(tbl, collapse="\n"), '</table><br>If a receiver is shown with a <span style="background-color:#ff8080">red background</span>, then it is connected by secure shell but does not have a data-streaming connection.  This might be because its master control process has died.  Troubleshooting via ssh tunnel is recommended.<br><br>If an SG has a streaming connection but no tunnel port, you cannot connect to its web interface.  Wait 5 minutes and check again whether the tunnel port has been assigned.', sep="\n")

    res$write(html)
    res$finish()
}

allReceiversApp = function(env) {
    req <- Rook::Request$new(env)
    res <- Rook::Response$new()

    res$header("Cache-control", "no-cache")

    html1 = "<div><ul>"

    f = dir(MOTUS_PATH$REMOTE_STREAMS, pattern=".*\\.sqlite$", full.names=TRUE)
    recv_with_db = sub(".sqlite$", "", basename(f))

    recv = ServerDB("select * from remote.receivers where verified=1 order by serno")

    recv$connNow = file.exists(file.path(MOTUS_PATH$REMOTE_CONNECTIONS, recv$serno))

    class(recv$creationdate) = c("POSIXt", "POSIXct")
    recv$db = f[match(recv$serno, recv_with_db)]

    recv = recv[order(1 - recv$connNow, recv$serno),]
    Now = Sys.time()
    now = as.numeric(Now)
    html = sprintf(
"
<br>This table generated at %s
<br>
<table rows=%d cols=%d border=1>
<tr><th>Serial No.</th><th>Lat</th><th>Lon</th><th>Boot<br>Count</th><th>Ants with Hits<br>Latest Hour</th><th>Latest Tag Hit</th><th>When</th><th>Hits Today</th><th>Total Hits</th></tr>",
      format(Now, "%Y %b %d %H:%M:%S GMT"),
      1 + nrow(recv), 9)

    tbl = character(nrow(recv))
    for (i in seq(along=tbl)) {
      if (is.na(recv$db)[i]) {
        tbl[i] = sprintf('<tr><td>%s</td><td colspan=8>No data received</td></tr>', recv$serno[i])
      } else {
        con = dbConnect(SQLite(), file.path(MOTUS_PATH$REMOTE_STREAMS, paste0(recv$serno[i], ".sqlite")))
        dbExecute(con, "pragma busy_timeout=300000")
        bootCount = dbGetQuery(con, "select max (parval) from metadata where parname = 'bootCount'")[1,1]
        if (is.na(bootCount))
          bootCount = 0
        gps = dbGetQuery(con, "select * from gps where ts != 'NaN' order by ts desc limit 1")
        tag = dbGetQuery(con, "select * from taghits order by ts desc limit 1")
        numHits = dbGetQuery(con, "select count(*) from taghits")
        numHitsToday = dbGetQuery(con, sprintf("select count(*) from taghits where ts >= %f", trunc(Now, "days")))
        devices = dbGetQuery(con, "select * from devices order by ts")
        lastCon = dbGetQuery(con, "select serverts from connections order by serverts desc limit 1")
        ports = unlist(dbGetQuery(con, sprintf("select distinct port from taghits where serverts >= %f", now-3600))[,1])
        if (nrow(lastCon) > 0) {
          lastCon = lastCon[1,1]
        } else {
          lastCon = 0
        }
        if (nrow(devices) > 0) {
          numAnts = sum(unlist(tapply(seq_len(nrow(devices)), devices$port,
            function(i) {
              j = tail(i, 1)
              devices$action[j] == 'A' && grepl("funcube", devices$type[j], ignore.case=TRUE)
            })))
        } else {
          numAnts = 0
        }
        dbDisconnect(con)
        class(tag$ts) = c("POSIXt", "POSIXct")

        if (is.null(tag) || nrow(tag) == 0) {
          tag = list(tagID = 0, antFreq=0, port=0, ts=structure(0, class=c("POSIXt", "POSIXct")))
          numHits = numHitsToday = 0
        }

        if (is.null(gps) || nrow(gps) == 0) {
          gps = list(lat=0, lon=0)
          tag$ts[1] = structure(tag$serverts[1], class=c("POSIXt", "POSIXct"))
        }

        try({
        tbl[i] = sprintf('<tr><td style="background-color: %s">%s</td><td>%.4f</td><td>%.4f</td><td>%d</td><td>%s</td><td>%d @ %.3f on Ant %d</td><td>%s ago</td><td>%.0f</td><td>%.0f</td></tr>',
             (if (recv$connNow[i]) "#80ff80" else if (now - lastCon < 600) "#ffff80" else "#ff8080"),
             recv$serno[i],
             gps$lat,
             gps$lon,
             bootCount,
             paste(sort(ports), collapse=", "),
             tag$tagID[1], tag$antFreq[1], tag$port[1],
             format(round(diff(c(tag$ts[1], Now)), 3)),
             numHitsToday,
             numHits)
      }, silent=TRUE)
      }
    }
    html = paste(html, paste(tbl, collapse="\n"), "</table>", sep="\n")

    res$write(html)
    res$finish()
}

getUploadTokenApp =  function(env) {
    req <- Rook::Request$new(env)
    res <- Rook::Response$new()
    res$header("Cache-control", "no-cache")

    user <- req$GET()[['user']]
    email <- req$GET()[['email']]

    ## generate the token using openssl's rand_bytes

    rv = getUploadToken(user, email)

    res$write(sprintf('<pre>Token: %s<br><br>Email: %s<br><br>Expires:%s</pre>', rv$token, email, format(rv$expiry, "%Y %b %d %H:%M:%S GMT")))
    res$finish()
}
