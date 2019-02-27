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

syncServer = function(tracing = FALSE, fileEvent="CLOSE_WRITE", defaultMotusUserID = 347, defaultMotusProjectID = 1) {
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

        if (! is.na(as.integer(parts["method"]))) {
            ## only valid method so far is an integer, representing the tunnel port #
            serno = parts["serno"]
            method = parts["method"]
            motusUserID = parts["motusUserID"]
            motusProjectID = parts["motusProjectID"]
            isTesting = parts["isTesting"]

            if (tracing)
                browser()

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

            ## only create the job if there isn't already an unfinished syncReceiver job for this SG
            if (length(Jobs[type=='syncReceiver' & done==0 & .$serno==R(serno)]) == 0) {
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
            motusLog("Unknown method for sync server", basename(touchFile))
        }
    }
    motusLog("Sync server stopped")
    quit(save="no")
}
