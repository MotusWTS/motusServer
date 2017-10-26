#' reply to http requests for information on the processing queue; API version
#'
#' @param port integer; local port on which to listen for requests;
#' default: 0x57A7
#'
#' @param tracing logical; if TRUE, run interactively, allowing local user
#' to enter commands.
#'
#' @param maxRows integer; maximum number of rows to return per request.
#' Default: 1000
#'
#' @return does not return; meant to be run as a server.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

statusServer2 = function(port = 0x57A7, tracing=FALSE, maxRows=1000L) {

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
## Note that we re-use authenticate_user from statusServer.

allStatusApps = c("status_api_info", "list_jobs", "_shutdown", "authenticate_user")

sortColumns = c("ctime", "mtime", "id", "type", "motusProjectID", "motusUserID")
sortCriteria = c(sortColumns, paste(sortColumns, "desc"))

#' add condition(s) to the where clause; strip
#' any leading "where " from the items in clauses,
#' then join them together using conj and add a preceding "where "
makeWhere = function(clauses, conj="and") {
    clauses = sub("^where ", "", clauses, ignore.case=TRUE)
    return(paste0("where ", paste0("(", clauses, ")", collapse = conj)))
}

#' add condition(s) to the order by clause
addToOrder = function(order, new) {
    for (n in new) {
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
            maxRows = MAX_ROWS_PER_REQUEST
        )
    )
}

#' return a list of jobs, sorted by user-selected criteria

list_jobs = function(env) {
    json = fromJSON(parent.frame()$postBody["json"])

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
    jobID     = safe_arg(select, jobID, int, scalar=FALSE)
    stump     = safe_arg(select, stump, int)
    type      = safe_arg(select, type, char, scalar=FALSE)
    done      = safe_arg(select, done, int)
    log       = safe_arg(select, log, char)

    ## ordering
    sortBy = safe_arg(order, sortBy, char, scalar=FALSE)
    lastKey = safe_arg(order, lastKey, num, scalar=FALSE)

    ## options
    includeUnknownProjects = isTRUE(safe_arg(options, includeUnknownProjects, logical))
    countOnly              = isTRUE(safe_arg(options, countOnly, logical))
    full                   = isTRUE(safe_arg(options, full, logical))
    includeSubjobs         = isTRUE(safe_arg(options, includeSubjobs, logical))

    ## validate access

    if (is.null(projectID))
        projectID = auth$projects
    if (! (is.null(userID) || userID == auth$userID || auth$userType == "administrator")) {
        return(error_from_app("not authorized for that userID"))
    }

    ## generate where clause from selectors

    if (includeSubjobs)
        where = NULL
    else
        where = makeWhere("pid is null")  ## only top-level jobs; these have no parent id
    if (is.null(projectID)) {
        projwhere = NULL
    } else {
        projwhere = sprintf("motusProjectID in (%s)", paste(projectID, collapse=","))
    }
    if (isTRUE(includeUnknownProjects))
        projwhere = makeWhere(c(projwhere, "motusProjectID is null"), conj="or")
    where = c(where, projwhere)
    if (!is.null(userID))
        where = c(where, sprintf("motusUserID = %d", userID))
    if (!is.null(jobID))
        where = c(where, sprintf("id in (%s)", paste0("'", jobID, "'", collapse=",")))
    if (!is.null(stump))
        where = c(where, sprintf("stump = %d", stump))
    if (!is.null(type))
        where = c(where, sprintf("type in (%s)", paste0("'", type, "'", collapse=",")))
    if (!is.null(done))
        where = c(where, switch(as.character(done), `1` = "done > 0", `0` = "done = 0", `-1` = "done < 0"))
    if (!is.null(log))
        where = c(where, sprintf("data glob '%s'", log))

    where = makeWhere(where)
    ## generate order by and additional where clause items for paging

    if (is.null(sortBy)) {
        sortBy = c("mtime desc")
    } else if (! all (sortBy %in% sortCriteria)) {
        return(error_from_app("invalid sortBy"))
    }

    if (! (is.null(lastKey) || length(lastKey) == length(sortBy))) {
        return(error_from_app("invalid number of `lastKey` values for given `sortBy`"))
    }

    if (! is.null(lastKey)) {
        sortByCols = sub(" desc$", "", sortBy)
        sortByOp = ifelse(grepl(" desc$", sortBy), "<", ">")
        where = makeWhere(where, sprintf("%s %s %f", sortByCols, sortByOp, lastKey))
    }

    order = ""
    for (sb in sortBy)
        order = addToOrder(order, sb)

    ## pull out appropriate jobs and details

    if (isTRUE(countOnly)) {

        query = sprintf("
select
   count(*)
from jobs
%s",
where)
    } else {
        query = sprintf("
select
   id,
   pid,
   stump,
   ctime,
   mtime,
   type,
   done,
   queue,
   path,
   motusUserID,
   motusProjectID
   %s
from
   jobs
%s
%s
limit %d",
if (isTRUE(full)) ", data" else "",
where,
order,
MAX_ROWS_PER_REQUEST
)
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

#' dump details of job j to res, as ith job listing
#' @param res Rook::response object
#' @param j job
#' @param i integer; index in list of jobs to be displayed

dumpJobDetails = function(res, j, i) {
    j = Jobs[[j]]
    res$write(paste0('<div class="jobDetails jobDetails', i, '" style="display:none">'))
    info = blob(j)
    replyTo = paste(info$replyTo, collapse=", ")
    if (is.null(replyTo))
        replyTo = "none"

    log = info$log_
    summary = info$summary_
    info = info[! (grepl("_$", names(info)) | names(info) == "replyTo")]
    params = paste(names(info), info, sep="=", collapse=", ")
    if (isTRUE(nchar(log) > 10000))
        log = paste0(substr(log, 1, 5000), "\n   ...\n", substring(log, nchar(log)-5000), "\n")
    res$write(sprintf("<h3>Status for job %d</h3><pre><b>Created Date:</b> %s\n<b>Last Activity:</b> %s\n<b>Sender:</b> %s\n<b>Parameters:</b> %s\n<b>Queue: </b>%s\n<b>Products:</b><pre>%s</pre><b>Summary: </b>%s</pre><h4>Log:</h4><pre>%s\n</pre>",
                      j,
                      format(TS(ctime(j))),
                      format(TS(mtime(j))),
                      replyTo,
                      params,
                      if (is.na(j$queue)) "None" else paste(j$queue),
                      if (is.null(j$products_)) "None" else paste(sprintf("   <a href=\"%s\">%s</a>", j$products_, basename(j$products_)), collapse="\n"),
                      if (is.null(summary)) "" else summary,
                      paste0("   ", gsub("\n", "\n   ", log, fixed=TRUE))
                      )
              )
    res$write("</div>")
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
    meta = safeSQL(getMotusMetaDB())
    ## get most recent project, site for each receiver deployment
    projSite = meta(sprintf("select t1.serno as Serno, t3.label as Project, t1.name as Site, t3.id as projectID from recvDeps as t1 left join recvDeps as t2 on t1.serno=t2.serno and t1.tsStart < t2.tsStart join projs as t3 on t1.projectID=t3.id where t1.serno in ('%s') and t2.serno is null", paste0("SG-", recv, collapse="','")))
    meta(.CLOSE=TRUE)

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
                anchor = sprintf('<a href="http://live.sensorgnome.org/SESSION_SG-%s_%s" style="color: #000000">%s</a>',
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
