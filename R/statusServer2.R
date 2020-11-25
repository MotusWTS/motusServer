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

allStatusApps = c("status_api_info",
                  "list_jobs",
                  "_shutdown",
                  "authenticate_user",
                  "process_new_upload",
                  "list_receiver_files",
                  "get_receiver_file",
                  "get_receiver_info",
                  "get_job_stackdump",
                  "retry_job",
                  "get_upload_info",
                  "serno_collision_rules",
                  "get_param_overrides",
                  "delete_param_overrides",
                  "add_param_override",
                  "describe_program",
                  "rerun_receiver"
                  )

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
    serno     = safe_arg(select, serno, char)

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
    excludeSync            = isTRUE(safe_arg(options, excludeSync, logical))
    limit                  = safe_arg(options, limit, int)
    if (is.null(limit))
        limit = MAX_ROWS_PER_REQUEST
    else
        limit = min(limit, MAX_ROWS_PER_REQUEST)

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
    if (! length(projectID)) {
        projwhere = NULL
    } else if (all(is.na(projectID))) {
        projwhere = sprintf("t1.motusProjectID is null")
    } else {
        projwhere = sprintf("t1.motusProjectID in (%s)", paste(projectID, collapse=","))
    }
    if (isTRUE(includeUnknownProjects))
        projwhere = makeWhere(c(projwhere, "t1.motusProjectID is null"), conj="or")
    where = c(where, projwhere)
    if (!is.null(userID)) {
        if (is.na(userID))
            where = c(where, "t1.motusUserID is null")
        else
            where = c(where, sprintf("t1.motusUserID = %d", userID))
    }
    if (!is.null(jobID))
        where = c(where, sprintf("t1.id in (%s)", paste0("'", jobID, "'", collapse=",")))
    if (!is.null(stump)) {
        ## allow for having been given a subjob's ID rather than that of the top-level job.
        stumpID = ServerDB("select stump from jobs where id=%d", stump)[[1]]
        ## not found, so propagate the query as-is, which should return no rows
        ## Otherwise, we were collapsing this part of the `where` clause, leading
        ## to no filtering, and a return of the entire dataset!
        ## See:  https://github.com/jbrzusto/motusServer/issues/381

        if (length(stumpID) == 0)
            stumpID = stump
        where = c(where, sprintf("t1.stump = %d", stumpID))
    }
    if (!is.null(type))
        where = c(where, sprintf("t1.type in (%s)", paste0("'", type, "'", collapse=",")))
    if (excludeSync)
        where = c(where, "t1.type <> 'syncReceiver'")
    if (!is.null(done))
        where = c(where, switch(as.character(done), `1` = "t1.done > 0", `0` = "t1.done = 0", `-1` = "t1.done < 0"))
    if (!is.null(log))
        where = c(where, sprintf("t2.data glob '%s'", log))
    if (!is.null(serno))
        where = c(where, sprintf("json_extract(t2.data, '$.serno')='%s'", serno))

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
            if (! is.na(lastKey[[1]]))
                w = sprintf("%s %s %f", sortBy[1], op, lastKey[[1]])
            else
                w = sprintf("%s is not null", sortBy[1])
        }
        if (length(lastKey) > 1) {
            if (sortBy[1] == "t1.type") {
                w = paste0(w, sprintf(" or (%s = '%s' and t1.id %s %f)", sortBy[1], lastKey[[1]], op, lastKey[[2]]))
            } else {
                if (! is.na(lastKey[[1]]))
                    w = paste0(w, sprintf(" or (%s =  %f  and t1.id %s %f)", sortBy[1], lastKey[[1]], op, lastKey[[2]]))
                else
                    w = paste0(w, sprintf(" or (%s is null  and t1.id %s %f)", sortBy[1], op, lastKey[[2]]))
            }
        }
        where = makeWhere(c(where, w))
    }

    order = ""
    for (i in seq(along=sortBy))
        order = addToOrder(order, sortBy[i], sortDesc, ! forwardFromKey)

    ## pull out appropriate jobs and details

    if (isTRUE(countOnly)) {
        if (isTRUE(errorOnly)) {
            where = makeWhere(c(where, "t2.done < 0"))
            query = sprintf("
select
   count( distinct t1.id ) as count
from
   jobs as t1
   left join jobs as t2 on t2.stump=t1.id
   %s
", where)
        } else {
            query = sprintf("
select
   count(*) as count
from
   jobs as t1
%s",
where,
having)
        }
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
if (is.null(stump)) limit else -1
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

    auth = validate_request(json)
    if (inherits(auth, "error")) return(auth)

    projectID = safe_arg(json, projectID, int)
    userID = safe_arg(json, userID, int)
    email = safe_arg(json, email, character)

    if (is.null(projectID))
        return(error_from_app("missing integer projectID"))
    if (! projectID %in% auth$projects)
        return(error_from_app("user does not have permissions for project"))
    if (is.null(userID))
        return(error_from_app("missing integer userID"))
    ## don't use safe_arg here; it doubles single quotes for use in queries.
    path = as.character(json$path)
    if (is.null(path))
        return(error_from_app("missing path"))
    ## convert back-slashes to forward slashes
    path = gsub("\\", '/', path, fixed=TRUE)
    comps = strsplit(path, '/', fixed=TRUE)[[1]]
    if (any(comps == ".."))
        return(error_from_app("path is not allowed to contain any '/../' components"))
    if (grepl('"', path, fixed=TRUE))
        return(error_from_app("path is not allowed to contain any '\"' characters"))
    realpath = file.path(MOTUS_PATH$UPLOADS_PARTIAL, path)
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

    ## debugging: if path begins with 'testing/', file is ignored, and a message is sent.
    if (isTRUE(comps[1] == "testing")) {
        return(error_from_app("testing file specified; everything looks okay, but I'm not processing it"))
    }
    ## move file and change ownership.  It will now have owner:group = "sg:sg" and
    ## permissions "rw-rw-r--"
    newDir = file.path(MOTUS_PATH$UPLOADS, userID)
    dir.create(newDir, showWarnings=FALSE)
    newPath = file.path(newDir, basename(realpath))
    ## use the shell, because file.rename() can't handle cross-filesystem moves...
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

    ## record the notification email address, if supplied
    if (!is.null(email) && nchar(email) > 0)
        j$replyTo = email

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
    isLotek = getRecvType(serno, lotekModel=FALSE) == "LOTEK"
    sql = safeSQL(getRecvSrc(serno))
    if (isLotek) {
        if (is.null(day)) {
            rv = sql("select strftime('%Y-%m-%d', datetime(day, 'unixepoch')) as day, 1 as count from (select distinct 24*3600*round(ts/(24*3600)) as day from DTAtags where ts is not null order by ts)")
        } else {
            rv = sql("select fileID, name, null as bootnum, null as monoBN, size, motusJobID as jobID from DTAfiles order by fileID")
        }
    } else {
        if (is.null(day)) {
            rv = sql('select day, count(*) as count from (select fileID, strftime("%Y-%m-%d", datetime(ts, "unixepoch")) as day from files) as j group by j.day order by j.day desc')
        } else {
            tsRange = c(0, 24*3600) + as.numeric(ymd_hms(paste(day, "00:00:00")))
            rv = sql("select fileID, name, bootnum, monoBN, size as contentSize, motusJobID as jobID from files where ts between :dayStart and :dayEnd order by fileID", dayStart=tsRange[1], dayEnd=tsRange[2])
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
    isLotek = getRecvType(serno, lotekModel=FALSE) == "LOTEK"
    repo = file.path(MOTUS_PATH$FILE_REPO, serno)
    if (isLotek) {
        files = dir(repo, full.names=TRUE)
        rv = data.frame(name=I(basename(files)), fileSize=file.size(files))
    } else {
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
    }
    return(as.tbl(rv))
}

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

    path = getRecvDBPath(serno)
    if (is.null(path))
        return(error_from_app("invalid receiver serial number (`serno`)"))
    if (!file.exists(path))
        return(error_from_app("receiver not known to motus"))

    isLotek = getRecvType(serno, lotekModel=FALSE) == "LOTEK"

    rv = list(serno=serno)

    if (is.null(day)) {
        db = files_from_recv_DB(serno)
        if (isLotek) {
            fc = db %>% mutate(countFS=1) %>% as.data.frame
        } else {
            fs = files_from_repo(serno)
            fc = db %>% full_join(fs, by="day") %>% arrange(desc(day)) %>% as.data.frame
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

#' return a single downloadable file for a receiver

get_receiver_file = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    ## parameters
    serno     = safe_arg(json, serno, char)
    fileID    = safe_arg(json, fileID, int)

    ## validate

    if (is.null(serno))
        return(error_from_app("must specify receiver serial number (`serno`)"))

    path = getRecvDBPath(serno)
    if (is.null(path))
        return(error_from_app("invalid receiver serial number (`serno`)"))
    if (!file.exists(path))
        return(error_from_app("receiver not known to motus"))

    isLotek = getRecvType(serno, lotekModel=FALSE) == "LOTEK"
    sql = safeSQL(getRecvSrc(serno))

    fi = sql("select * from %s where fileID=%d", SQL(if (isLotek) "DTAfiles" else "files"), fileID)
    isComp = TRUE
    if (isTRUE(nrow(fi) == 1)) {
        ## get path to file; note that Lotek files are not stored in a YYYY-MM-DD subfolder
        path = file.path(MOTUS_PATH$FILE_REPO,
                         serno,
                         if (isLotek) "" else format(structure(fi$ts, class=class(Sys.time())), "%Y-%m-%d"),
                         fi$name)
        if (isTRUE(fi$isDone > 0)) {
            return(return_file_from_app(paste0(path, ".gz"), name=basename(path), encoding="gzip"))
        } else {
            return(return_file_from_app(path))
        }
    }
    return_from_app(list(error="invalid fileID for this receiver"))
}

#' return information for a receiver

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

    path = getRecvDBPath(serno)
    if (is.null(path))
        return(error_from_app("invalid receiver serial number (`serno`)"))
    if (!file.exists(path))
        return(error_from_app("receiver not known to motus"))

    rv = list(serno=serno, receiverType=getRecvType(serno))

    deps = MetaDB("select * from recvDeps where serno=:serno order by tsStart desc", serno=serno)

    ## extract items which are the same in every row
    rv$deviceID = deps$deviceID[1]

    if (! isTRUE(rv$deviceID > 0)) {
        ## even if there is no deployment record for it, a known
        ## receiver will have a motus device ID
        rv$deviceID = getMotusDeviceID(serno)
    }

    ## drop no-longer-needed fields
    deps[c("deviceID", "receiverType", "id")] = NULL

    rv$deployments = deps
    proj = if (auth$userType == "administrator")
               ""
           else
               sprintf("and projectID in (%x)", paste(auth$projects, collapse=","))

    rv$products = ServerDB("select distinct URL from products where serno='%s' %s order by URL", serno, proj)[[1]]
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
        return(error_from_app("no stack dump available for job", jobID=jobID))
    return_from_app(list(jobID = jobID, URL = getDownloadURL(errorJobID = jobID), size=file.size(dumpfile), path=dumpfile))
}

#' retry job(s) with errors

retry_job = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    jobID = safe_arg(json, jobID, int, scalar=FALSE)

    message = safe_arg(json, message, character)

    j = Jobs[[jobID]]

    error = NULL ## assume no error

    if (is.null(j)) {
        error = "invalid jobID"
    } else {
        ## lock the jobs database (against another user making a retry request)
        lockSymbol("jobsDB")
        on.exit(lockSymbol("jobsDB", lock=FALSE))

        j = topJob(j)
        done = progeny(j)$done
        if (all(done > 0) && j$done > 0) {
            error = paste("All subjobs related to job ", jobID, " succeeded.\nThere is nothing to retry!")
        } else if (! any(c(done < 0, j$done < 0))) {
            error = paste("No subjobs related to job ", jobID, " have errors.\nPerhaps they have already been submitted for a retry?")
        }
        ## mark jobs with errors as not done

        if (j$done < 0)
            j$done = 0

        kids = progeny(j)[done < 0]  ## need to end up with a LHS object of
        ## class "Twig" for the subsequent
        ## assignment
        kids$done = 0
        jobIDs = as.integer(kids)
        types = kids$type

        msg = sprintf("Retrying subjob(s) %s of types %s.\nReason: %s", paste(kids, collapse=", "), paste(kids$type, collapse=", "),
                      if(is.null(message)) "none given" else message)

        jobLog(j, msg, summary=TRUE)
        jobLog(j, "--- (retry) ---")

        j$queue = 0L

        if (moveJob(j, MOTUS_PATH$QUEUE0)) {
            reply = "Job(s) moved to queue for retrying"
        } else {
            error = paste0("Failed to move job ", j, " to queue")
        }
    }
    if (is.null(error)) {
        return_from_app(list(
            jobs = list(
                jobID = jobIDs,
                type = types
            ),
            reply = reply
        )
        )
    } else {
        error_from_app(error)
    }
}

get_upload_info = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE)
    if (inherits(auth, "error")) return(auth)

    ## parameters
    uploadID  = safe_arg(json, uploadID, int)
    sha1  = safe_arg(json, sha1, char)
    listContents = safe_arg(json, listContents, logical)

    ## default is to include list of contents
    if (is.null(listContents))
        listContents = TRUE

    ## validate

    if (is.null(uploadID) + is.null(sha1) != 1)
        return(error_from_app("must specify exactly one of `uploadID` or `sha1` for file"))

    if (!is.null(uploadID)) {
        info = MotusDB("select * from uploads where uploadID=%d", uploadID)
    } else {
        info = MotusDB("select * from uploads where sha1=%s", sha1)
    }
    if (!isTRUE(nrow(info) == 1))
        return(error_from_app("no such file"))

    ## info has uploadID, jobID, motusUserID, motusProjectID, filename, sha1, ts
    ## get file extension

    if (! isTRUE(info$motusProjectID %in% auth$projects))
        return(error_from_app("file has been uploaded but belongs to a project you don't have permissions for"))
    exists = FALSE
    try({
        info$path = file.path(MOTUS_PATH$UPLOADS, info$motusUserID, info$filename)
        info$size = file.size(info$path)
        exists = TRUE
        }, silent=TRUE)
    if (! exists)
        return(error_from_app("upload info in database but file does not exist!"))

    ## get contents, depending on file extension
    ext = tolower(regexPieces("(?i).(?<ext>7z|dta|zip|rar)$", info$filename)[[1]])
    contents = ""

    if (listContents && length(ext) > 0) {
        tryCatch({
            contents = switch(ext,
                              `dta` = paste0("First 10 lines:\n   ", paste0(readLines(info$path, n=10), collapse="\n   "), "\n"),
                              `zip` = safeSys("unzip", "-v", info$path),
                              `7z` = safeSys("7z", "l", info$path),
                              `rar` = safeSys("unrar", "-t", info$path),
                              "unknown file type; I don't know how to summarize contents!"
                              )
        }, error=function(e) {
            contents <<- paste0("Unable to list contents for archive ", basename(info$path), ":\n   ", e)
        }
        )
    }

    return_from_app(list(
        uploadID = info$uploadID,  ## in case sha1 was specified by caller
        name = basename(info$filename),
        path = dirname(info$path),
        userID = info$motusUserID,
        projectID = info$motusProjectID,
        jobID = info$jobID,
        ts = info$ts,
        size = info$size,
        contents = contents,
        sha1 = info$sha1))
}

#' get, create, or delete rules for resolving receiver serial number collisions

serno_collision_rules = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    action  = safe_arg(json, action, char              )
    id      = safe_arg(json, id,     int,  scalar=FALSE)
    serno   = safe_arg(json, serno,  char, scalar=FALSE)
    cond    = safe_arg(json, cond,   char, scalar=FALSE)
    suffix  = safe_arg(json, suffix, char, scalar=FALSE)

    if (is.null(action))
        return(error_from_app("must specify action"))

    ## basic sanity checks

    if (action %in% c("get", "delete")) {
        where = NULL
        if (! is.null(id))
            where = makeWhere(c(where, sprintf("id in (%s)", paste(id, collapse=","))))
        if (! is.null(serno))
            where = makeWhere(c(where, sprintf("serno in (%s)", paste0("'", serno, "'", collapse=","))), "or")
        if (action == "delete" && is.null(where))
            return(error_from_app("action 'delete' requires 'id' or 'serno'"))
    } else if (action == "put") {
        lens = range(c(length(serno), length(cond), length(suffix)))
        if (diff(lens) > 0 || lens[1] == 0)
            return(error_from_app("action 'put' requires that 'serno', 'cond', and 'suffix' be specified and of the same length"))
        error = NULL
        tryCatch({
            parse(text=cond)
        }, error = function(e) {
            error <<- as.character(e)
        })
        if (! is.null(error)) {
            return(error_from_app(paste0("got error parsing `cond`: ", error)))
        }
        ## Note: only this single-threaded modifies the serno_collision_rules table,
        ## so we can get the ids of entries we're about to add by
        ids = seq_len(lens[1]) + MetaDB("select max(id) from serno_collision_rules")[[1]]
        for (i in 1:lens[1])
            MetaDB("insert into serno_collision_rules (id, serno, cond, suffix) values (%d, %s, %s, %s)", ids[i], serno[i], cond[i], suffix[i], .QUOTE=TRUE)
        where = makeWhere(sprintf("id in (%s)", paste(ids, collapse=",")))
    } else {
        return(error_from_app("unknown action"))
    }
    rv = MetaDB("select id, serno, cond, suffix from serno_collision_rules %s order by id", if (is.null(where)) "" else where)
    if (action == "delete")
        MetaDB("delete from serno_collision_rules %s", where)

    return_from_app(rv)
}



## get param_overrides

## get_param_overrides(id, projectID, serno, progName, authToken) - administrative users only

##   - id: optional; integer array of param override IDs
##   - projectID: optional; integer array of motus project IDs
##   - serno: optional; string array of receiver serial numbers
##   - progName: optional; string array of program names to which parameter overrides apply

## return the set of all parameter overrides matching all specified criteria. If no criteria are supplied, then all overrides are returned. The returned object has these array items:

##   - id: integer; IDs of parameter overrides
##   - projectID: integer; motus project IDs (each can be null)
##   - serno: character; device serial numbers (each can be null)
##   - tsStart: double; starting timestamps (each can be null; seconds since 1 Jan 1970 GMT)
##   - tsEnd: double; ending timestamps (each can be null; seconds since 1 Jan 1970 GMT)
##   - monoBNlow: integer; starting boot session numbers (each can be null; used for SGs only)
##   - monoBNhigh: integer; ending boot session numbers (each can be null; used for SGs only)
##   - progName: character; names of programs to which override applies; typically 'find_tags_motus'
##   - paramName: character; names of parameters (e.g. 'default_freq')
##   - paramVal: double; values for parameters (each can be null if parameter is just a flag)
##   - why: character; human-readable reason for each override

get_param_overrides = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    id        = safe_arg(json, id,        int,  scalar=FALSE)
    projectID = safe_arg(json, projectID, int,  scalar=FALSE)
    serno     = safe_arg(json, serno,     char, scalar=FALSE)
    progName  = safe_arg(json, progName,  char, scalar=FALSE)

    where = "where 1 "
    if (! is.null(id)) {
        where = paste0("and (id in (", paste(id, collapse=","), "))")
    }
    if (! is.null(projectID)) {
        where = paste0(where, "and (projectID in (", paste(projectID, collapse=","), "))")
    }
    if (! is.null(serno)) {
        where = paste0(where, "and (serno in (", paste(serno, collapse=","), "))")
    }
    if (! is.null(serno)) {
        where = paste0(where, "and (progName in (", paste(progName, collapse=","), "))")
    }
    rv = MetaDB(paste0("select * from paramOverrides ", where))
    return_from_app(rv)
}

## delete_param_overrides

## delete_param_overrides(id, authToken) - administrative users only

##   - id: integer array of param override IDs

## delete the parameter overrides whose IDs are in id, returning a boolean array of the same length indicating which IDs were deleted.

delete_param_overrides = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    id        = safe_arg(json, id,        int,  scalar=FALSE)

    if (is.null(id)) {
        return(error_from_app("Need to specify one or more ids of param_overrides to delete"))
    }
    where = paste0("where id in (", paste(id, collapse=","), ")")
    have = MetaDB(paste0("select id from paramOverrides ", where))
    MetaDB(paste0("delete from paramOverrides ", where))
    return_from_app(data.frame(deleted=! (id %in% have)))
}

## add_param_override

## add_param_override(projectID, serno, tsStart, tsEnd, monoBNlow, monoBNhigh, progName, paramName, paramVal, why, authToken)

##   - projectID: integer; motus project IDs (can be null)
##   - serno: character; device serial numbers (can be null)
##   Exactly one of `serno` or `projectID` must be specified.

##   - tsStart: double; starting timestamp (can be null; seconds since 1 Jan 1970 GMT)
##   - tsEnd: double; ending timestamp (can be null; seconds since 1 Jan 1970 GMT)
##   - monoBNlow: integer; starting boot session number (can be null; used for SGs only)
##   - monoBNhigh: integer; ending boot session number (can be null; used for SGs only)
##   - progName: character; name of program to which override applies; typically 'find_tags_motus'
##   - paramName: character; name of parameter (e.g. 'default_freq')
##   - paramVal: double; value for parameter (can be null if parameter is just a flag)
##   - why: character; human-readable reason for override

## returns an object with this item:

##   - id: integer ID of new parameter override

## or an item called error if the override already exists or there were problems with the specified parameters.
## describe_program

add_param_override = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    projectID    = safe_arg(json, projectID,  int,     scalar=TRUE, nullValue="null")
    serno        = safe_arg(json, serno,      char,    scalar=TRUE, nullValue="null")
    tsStart      = safe_arg(json, tsStart,    numeric, scalar=TRUE, nullValue="null")
    tsEnd        = safe_arg(json, tsEnd,      numeric, scalar=TRUE, nullValue="null")
    monoBNlow    = safe_arg(json, monoBNlow,  int,     scalar=TRUE, nullValue="null")
    monoBNhigh   = safe_arg(json, monoBNhigh, int,     scalar=TRUE, nullValue="null")
    progName     = safe_arg(json, progName,   char,    scalar=TRUE)
    paramName    = safe_arg(json, paramName,  char,    scalar=TRUE)
    paramVal     = safe_arg(json, paramVal,   numeric, scalar=TRUE)
    why          = safe_arg(json, why,        char,    scalar=TRUE, nullValue="")
    if (is.null(serno) && is.null(projectID))
        return(error_from_app("Need to specify one of serno, projectID"))

    if (is.null(progName) || is.null(paramName) || is.null(paramVal) || is.null(why))
        return(error_from_app("Need to specify all of progName, paramName, paramVal, why"))

    if (is.null(serno)) serno = ""

    ## Note the use of '%s' format strings for numeric fields; R's
    ## sprintf converts automatically from numerics to strings, and
    ## this lets us use "null" for permitted missing values.

    MetaDB("insert into paramOverrides (projectID,serno,tsStart,tsEnd,monoBNlow,monoBNhigh,progName,paramName,paramVal,why) values (%d,%s,%s,%s,%s,%s,%s,%s,%f,%s)",
           projectID,
           serno,
           tsStart,
           tsEnd,
           monoBNlow,
           monoBNhigh,
           progName,
           paramName,
           paramVal,
           why,
           .QUOTE=TRUE)

    return_from_app(MetaDB("select id from paramOverrides where rowid=last_insert_rowid()"))
}

## describe_program(progName, authToken) - administrative users only

##   - progName: (optional) string scalar giving name of program for which
##   to return information

## return information about a program.

## If progName is not specified, then return an object with this array item:

##   - progName: string array of possible values for `progName`.

## If progName is specified, then return an object with these items:
##   - version: string array of current version of program, from `git describe`
##   - build_ts: numeric timestamp of build
##   - options:  a list of parameter descriptions; each item has these fields:
##      - name: character;
##      - description: character; human-readable description
##      - default: real, integer, or logical;
##      - type: "real", "logical", or "integer"

describe_program = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=FALSE, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    progName     = safe_arg(json, progName,   char,    scalar=TRUE)
    if (is.null(progName)) {
        return(return_from_app(list(progName=c("find_tags_motus"))))
    }
    if (progName == "find_tags_motus") {
        return(return_from_app(system("find_tags_motus --info_only", intern=TRUE), isJSON=TRUE))
    }
    error_from_app("Unknown program")
}

## Reprocess a receiver's files

rerun_receiver = function(env) {
    json = fromJSON(parent.frame()$postBody["json"], simplifyVector=FALSE)

    if (tracing)
        browser()

    auth = validate_request(json, needProjectID=TRUE, needAdmin=TRUE)
    if (inherits(auth, "error")) return(auth)

    userID = auth$userID
    projectID = auth$projectID
    serno = safe_arg(json, serno, char, scalar=FALSE)
    minBN = safe_arg(json, minBN, int)
    maxBN = safe_arg(json, maxBN, int)

    if (is.null(serno))
        return(error_from_app("must specify receiver serial number (`serno`)"))
    path = getRecvDBPath(serno)
    if (is.null(path))
        return(error_from_app("invalid receiver serial number (`serno`)"))
    if (!file.exists(path))
        return(error_from_app("receiver not known to motus"))

    if (is.null(minBN)) {
        j = newJob("rerunReceiver", .parentPath=MOTUS_PATH$INCOMING, serno=serno, exportOnly=FALSE, cleanup=TRUE, motusUserID = userID, motusProjectID = projectID, .enqueue=FALSE)
    } else if (is.null(maxBN)) {
        j = newJob("rerunReceiver", .parentPath=MOTUS_PATH$INCOMING, serno=serno, monoBN=c(minBN, minBN), exportOnly=FALSE, cleanup=TRUE, motusUserID = userID, motusProjectID = projectID, .enqueue=FALSE)
    } else {
        j = newJob("rerunReceiver", .parentPath=MOTUS_PATH$INCOMING, serno=serno, monoBN=c(minBN, maxBN), exportOnly=FALSE, cleanup=TRUE, motusUserID = userID, motusProjectID = projectID, .enqueue=FALSE)
    }
    jobID = unclass(j)
    jobLog(j, paste0("Rerunning receiver ", serno, ", boot numbers ", minBN, " to ", maxBN), summary=TRUE)
    j$queue = "0"
    safeSys("sudo", "chown", "sg:sg", j$path)
    moveJob(j, MOTUS_PATH$QUEUE0)
    cat("Job", jobID, "has been entered into queue 0\n")
    return_from_app(list(jobID = jobID))
}
