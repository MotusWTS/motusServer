#' reply to http requests for information on the processing queue
#'
#' @param port integer; local port on which to listen for requests
#'
#' @param tracing logical; if TRUE, run interactively, allowing local user
#' to enter commands.
#'
#' @return does not return; meant to be run as a server.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

statusServer = function(port, tracing=FALSE) {
    ## open a connection to the server database
    DB <<- ensureServerDB()
    loadJobs()

    library(Rook)
    library(hwriter)

    ## save server in a global variable in case we are tracing

    SERVER <<- Rhttpd$new()

    ## add each function below as an app

    for (f in allApps)
        SERVER$add(RhttpdApp$new(app = get(f), name = f))

    SERVER$start(port = port)

    if (! tracing) {
        ## sleep while awaiting requests
        suspend_console()
    }
}

## a string giving the list of apps for this server

allApps = c("latestJobs", "jobStatus", "queueStatus")

## write a string providing a header for navigating among app pages

writeHeader = function(res, which) {
    which = which(allApps == which)
    links = sprintf('<a href="/custom/%s">%s</a>', allApps, allApps)
    ## remove link for current page
    links[which] = paste0("<b>", allApps[which], "</b>")
    nav = paste0('<pre>', paste0(links, collapse="   |   "), '\n\n</pre>')
    res$write(nav)
}

latestJobs = function(env) {

    ## return summary of latest top jobs
    ## parameters:
    ##   - n:  number of jobs to show
    ##   - k:  max jobID to show (0 means unknown); if negative, - min jobID to show.
    ##

    req <- Rook::Request$new(env)
    res <- Rook::Response$new()

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "text/html; charset=utf-8")

    writeHeader(res, "latestJobs")

    n <- as.integer(req$GET()[['n']])[1]
    if (! isTRUE(n > 0 && n <= 500))
        n = 20
    k <- as.integer(req$GET()[['k']])[1]
    if (! isTRUE(k >= 0))
        k = 0

    if (k == 0)
        k = DB("select max (id) from jobs where pid is null")[[1]]
    if (k > 0) {
        jj = DB("select id from jobs where pid is null and id <= :k order by id desc limit :n", k=k, n=n)[[1]]
    } else {
        jj = DB("select id from jobs where pid is null and id >= :k order by id desc limit :n", k=-k, n=n)[[1]]
    }

    if (length(jj) == 0) {
        jj = DB(sprintf("select id from jobs where pid is null order by id %s limit :n", if (k > 0) "desc" else ""), n=n) [[1]]
    }

    res$write("<pre>")
    if (min(jj) > 1)
        res$write(sprintf('<a href="/custom/latestJobs?n=%d&k=%d">Prev</a>    ', n, min(jj) - 1))

    res$write(sprintf('<a href="/custom/latestJobs?n=%d&k=%d">Next</a>', n, -(max(jj) + 1)))

    info = DB("select id, json_extract(data, '$.auth.username'), ctime, mtime, type, done from jobs where id in (:jj) order by id desc", jj=jj)
    class(info$ctime) = class(info$mtime) = c("POSIXt", "POSIXct")

    res$write("\n\n</pre>")
    ## any expression from here on can't use the original names for the columns of info
    names(info) = c("ID", "User (sensorgnome.org)", "Created Date/Time", "Last Activity Date/Time", "Job Type", "Done? (0=no, 1=yes, -1=error)")
    res$write(hwrite(info, border=0, row.style=list('font-weight:bold'), col.link=list(sprintf("/custom/jobStatus?j=%d", jj), NA, NA, NA, NA, NA),
                     row.bgcolor=rep(c("#ffffff", "#f0f0f0"), length=nrow(info))))
    res$finish()
}

jobStatus = function(env) {
    ## return summary of a top job
    ## parameters:
    ##   - j:  job number; if positive, use the top job with the smallest id >= j;
    ##  if negative, use the top job with the largest id <= -j;

    req <- Rook::Request$new(env)
    res <- Rook::Response$new()

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "text/html; charset=utf-8")

    writeHeader(res, "jobStatus")

    j <- as.integer(req$GET()[['j']])[1]

    if (! isTRUE(abs(j) > 0)) {
        ## get most recent job
        j = DB("select max (id) from jobs where pid is null")[[1]]
    } else if (j > 0) {
        j = DB("select min (id) from jobs where pid is null and id >= :j", j=j)[[1]]
        if (is.na(j))
            j = DB("select max (id) from jobs where pid is null")[[1]]
    } else {
        j = DB("select max (id) from jobs where pid is null and id <= :j", j=-j)[[1]]
        if (is.na(j))
            j = DB("select min (id) from jobs where pid is null")[[1]]
    }

    j = Jobs[[j]]

    if (is.null(j)) {
        res$write("Error: invalid job number specified")
        res$finish()
        return()
    }

    res$write("<pre>")
    if (j > 1)
        res$write(sprintf('<a href="/custom/jobStatus?j=%d">Prev</a>    ', -(j - 1)))

    res$write(sprintf('<a href="/custom/jobStatus?j=%d">Next</a>', j + 1))

    replyTo = paste(j$replyTo, collapse=", ")
    if (is.null(replyTo))
        replyTo = "none"

    res$write(sprintf("<h3>Status for job %d</h3><pre><b>Created Date:</b> %s\n<b>Last Activity:</b> %s\n<b>Sender:</b> %s\n<b>Queue: </b>%s</pre><h4>Log:</h4><pre>%s\n</pre>",
                      j,
                      format(TS(ctime(j))),
                      format(TS(mtime(j))),
                      replyTo,
                      if (is.na(j$queue)) "None" else paste(j$queue),
                      paste0("   ", gsub("\n", "\n   ", j$log, fixed=TRUE))
                      )
              )
    res$finish()
}

queueStatus = function(env) {
    ## return summary of master queue and processing queues
    ## parameters:
    ## - none so far

    req <- Rook::Request$new(env)
    res <- Rook::Response$new()

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "text/html; charset=utf-8")

    writeHeader(res, "queueStatus")

    ## num jobs waiting to be assigned to a processor
    q0 = DB("select count(*) from jobs where pid is null and queue=0")[[1]]

    ## ids of next 20 jobs in queue 0
    q0j = DB("select id from jobs where pid is null and queue=0 order by id desc limit 20")[[1]]

    ## num jobs assigned to each processor
    qq = DB("select queue as Processor, count(*) as NumJobs from jobs where pid is null and queue > 0 group by queue")

    ## ids of queued jobs for each processor
    qqj = DB("select queue, id from jobs where pid is null and queue > 0 order by queue, id")

    ## num unfinished tasks per processor
    qu = DB("select queue as Processor, count(*) as NumTasks from jobs where done == 0 and queue > 0 group by queue")

    ## num jobs in email queue
    qm = DB("select count(*) from jobs where pid is null and queue is null and type='email'")[[1]]

    ## number of processServers running
    pids = dir("/sgm", pattern="^processServer[0-9]+.pid$", full.names=TRUE)
    qr = regexPieces("processServer(?<qn>[0-9]+).pid", pids)["qn"]

    ## number of emails in inbox, awaiting processing
    inb = length(dir("/sgm/inbox"))

    ## number of embargoed emails awaiting processing
    emb = length(dir("/sgm/inbox_embargoed"))

    ## is emailServer running?
    es = file.exists("/sgm/emailServer.pid")

    res$write(paste0(
        "<h3>Processing Status</h3>",
        "<h4>Emails</h4><pre>",
        "<b>Email Server running:</b>  ", if (es) "Yes" else "No", "\n",
        "<b>Messages embargoed, awaiting manual acceptance:</b>  ", if (length(emb) > 0) emb else "None", "\n",
        "<b>Messages in inbox, awaiting processing:</b>  ", if (length(inb) > 0) inb else "None", "\n",
        "<b>Messages being processed:</b>  ", if (length(qm) > 0) qm else "None", "\n",
        "</pre>",
        "<h4>Process Servers</h4><pre>",
        "<b>Servers running:</b>  ", if(length(pids) > 0) paste0(qr, collapse=", ") else "None", "\n",
        "<b>Jobs in master queue waiting for a processor</b>:  ", q0, "\n",
        "<b>First jobs in master queue:</b>  ", paste(sprintf('<a href="/custom/jobStatus?j=%d">%d</a>', q0j, q0j), collapse=", &nbsp;&nbsp;"), "\n",
        if(nrow(qq > 0)) paste0("<b>Jobs assigned to each processor:</b>\n", paste(hwrite(qq, border=0))) else "",
        "\n</pre>"
        ))

    res$finish()
}
