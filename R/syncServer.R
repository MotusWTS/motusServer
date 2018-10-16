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

syncServer = function(tracing = FALSE, fileEvent="CLOSE_WRITE") {
    if(tracing)
        options(error=recover)

    ensureServerDirs()
    motusLog("Sync server started")

    ## load jobs
    loadJobs()

    feed = getFeeder(MOTUS_PATH$SYNC, messages = fileEvent, tracing=tracing)

    ## kill off the inotifywait process when we exit this function
    on.exit(feed(TRUE), add=TRUE)

    repeat {
        touchFile = feed()             ## this might might wait a long time
        file.remove(touchFile)         ## the file is empty, was only needed to trigger this event
        parts = regexPieces("(?<method>.*):(?<serno>SG-[0-9A-Z]{12}):(?<motusUserID>[0-9]+):(?<motusProjectID>[0-9]+)", basename(touchFile))[[1]]
        if (! is.na(as.integer(parts["method"]))) {
            ## only valid method so far is an integer, representing the tunnel port #
            if (tracing)
                browser()

            ## only create the job if there isn't already an unfinished syncReceiver job for this SG
            if (length(Jobs[type=='syncReceiver' & done==0 & .$serno==R(parts["serno"])]) == 0) {
                j = newJob("syncReceiver", .parentPath=MOTUS_PATH$INCOMING, .enqueue=FALSE,
                           serno=parts["serno"],
                           method=parts["method"],
                           motusUserID=parts["motusUserID"],
                           motusProjectID=parts["motusProjectID"],
                           queue="0")
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
