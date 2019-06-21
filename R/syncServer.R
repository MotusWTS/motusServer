#' watch for attached receivers and sync files from them
#'
#' Watch for new files in \code{MOTUS_PATH$SYNC}.  When a file is
#' found, it's treated as describing a method and serial number for
#' syncing, and a new syncReceiver job is queued for the receiver, if
#' there isn't already an unfinished one for it. The syncReceiver job
#' is queued via /sgm/priority, bypassing jobs running from uploaded
#' data or manually on the server.  This is to provide relatively low
#' latency for both users watching online receivers, and because the
#' internet connection to the receiver might be intermittent.
#'
#' @param tracing logical scalar, default FALSE.  If TRUE, enter
#'     debug browser before handling each new file upload.
#'
#' @param fileEvent character scalar; default: "CLOSE_WRITE".
#' Empty files are created in \code{MOTUS_PATH$SYNC} via the
#' 'touch' command, so this is the last event in that case.
#'
#' @param defaultMotusUserID integer scalar; userID recorded for
#' job if we're unable to find an appropriate receiver deployment
#' and/or we're unable to
#' default: 347 = jeremy
#'
#' @param defaultMotusProjectID integer scalar; projectID recorded for
#' job if we're unable to find an appropriate receiver deployment;
#' default: 1 = motus Ontario array.
#'
#' @return This function does not return; it is meant for use in an R
#'     script run in the background.
#'
#' @note this depends on some other process creating files in
#' the folder \code{MOTUS_PATH$SYNC}.  In the motus set-up, this
#' will be done from the server at sensorgnome.org, which manages
#' and hosts networked SGs.
#'
#' @seealso \link{\code{handleSyncReceiver}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

syncServer = function(tracing = FALSE, fileEvent="CLOSE_WRITE", defaultMotusUserID = 347, defaultMotusProjectID = 0) {
    if(tracing)
        options(error=recover)

    ensureServerDirs()
    motusLog("Sync server started")

    ## open the motus metadata cache DB
    getMotusMetaDB()

    ## load jobs
    loadJobs()

    feed = getFeeder(MOTUS_PATH$SYNC, messages = fileEvent, tracing=tracing)

    ## kill off the inotifywait process when we exit this function
    on.exit(feed(TRUE), add=TRUE)

    repeat {
        touchFile = feed()             ## this might might wait a long time
        file.remove(touchFile)         ## the file is empty, was only needed to trigger this event
        ## lazy parse of filename which might look like
        ## /sgm_local/sync/method=1234,serno=SG-5016BBBK15A4,isTesting=TRUE

        parts = regexPieces("(?:method=(?<method>[^,]*))|(?:serno=(?<serno>SG-[0-9A-Z]{12}))|(?:motusUserID=(?<motusUserID>[0-9]+))|(?:motusProjectID=(?<motusProjectID>[0-9]+))|(?:isTesting=(?<isTesting>[[:alnum:]]+))", basename(touchFile))[[1]]

        if (! is.na(as.integer(parts["method"])) && ! is.na(parts["serno"])) {
            ## only valid method so far is an integer, representing the tunnel port #
            serno = parts["serno"]
            method = parts["method"]
            motusUserID = parts["motusUserID"]
            motusProjectID = parts["motusProjectID"]
            isTesting = parts["isTesting"]

            if (tracing)
                browser()

            ## handle known duplicate serial numbers
            ## TODO: add a new column to serno_collision_rules and use a method similar to that used in parseFilenames instead of hard-coding the serial number
            if(serno == 'SG-2616BBBK1111' & method == 40458)
                serno = paste0(serno, '_1')

            ## get sensible values for motus ProjectID and UserID
            if (is.na(motusProjectID)) {
                ## lookup the latest unterminated deployment for this receiver, and use that
                ## project ID
                motusProjectID = MetaDB("select projectID from recvDeps where serno = '%s' and tsEnd is null order by tsStart desc limit 1", serno)[[1]]
                if (length(motusProjectID) == 0)
                    motusProjectID = defaultMotusProjectID
            }
            if (is.na(motusUserID))
                motusUserID = defaultMotusUserID

            ## only create the job if any previous syncReceiver job for this SG has completed
            dosync = TRUE
            jj = query(Jobs, sprintf("select max(id) from jobs where type='syncReceiver' and json_extract(data, '$.serno') == '%s'", serno))[[1]]
            if (isTRUE(jj > 0)) {
                ## there's at least one sync job for this receiver; make sure it has completed
                ## by checking that none of its subjobs has status 0
                jj = query(Jobs, sprintf("select max(id) from jobs where stump=%d and done == 0", jj))[[1]]
                if (isTRUE(jj > 0)) {
                    dosync = FALSE
                    motusLog("Sync job underway for %s; not starting another", serno)
                }
            }
            if (dosync) {
                j = newJob("syncReceiver", .parentPath=MOTUS_PATH$INCOMING, .enqueue=FALSE,
                           serno=serno,
                           method=method,
                           motusUserID=motusUserID,
                           motusProjectID=motusProjectID,
                           queue="0")
                if (isTRUE(isTesting))
                    j$isTesting = TRUE
                moveJob(j, MOTUS_PATH$PRIORITY)
            }
            file.remove(touchFile)
        } else {
            motusLog("Unknown method for sync server: %s", basename(touchFile))
        }
    }
    motusLog("Sync server stopped")
    quit(save="no")
}
