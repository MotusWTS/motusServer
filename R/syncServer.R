#' watch for attached receivers and sync files from them
#'
#' Watch for new files in \code{MOTUS_PATH$SYNC}.  When a
#' file is found, it's assumed the name is the serial number
#' of an attached receiver.  New files from that receiver are
#' fetched with rsync, and a job to process them is enqueued
#' on a priority processServer.
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
#' @note this depends on some other process placing uploaded files into
#' the folder \code{MOTUS_PATH$SYNC}.  This is done by a shell script
#' launched from the sg_remote program that is run on the server
#' by each attached receiver.  The last step of the shell script is
#' to cause its own relaunch after a random time interval, via an
#' 'at' job.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

syncServer = function(tracing = FALSE, fileEvent="CLOSE_WRITE") {
    if(tracing)
        options(error=recover)

    ensureServerDirs()
    ensureServerDB()
    motusLog("Sync server started")

    ## load jobs
    loadJobs()

    feed = getFeeder(MOTUS_PATH$SYNC, messages = fileEvent, tracing=tracing)

    ## kill off the inotifywait process when we exit this function
    on.exit(feed(TRUE), add=TRUE)

    repeat {
        touchFile = feed()             ## this might might wait a long time
        file.remove(touchFile)         ## the file is empty, was only needed to trigger this event
        serno = basename(touchFile)
        serno = gsub("[^-[:alnum:]]", "", serno, perl=TRUE) ## sanitize possibly malicious serial number
        if (tracing)
            browser()

        j = newJob("syncReceiver", .parentPath=MOTUS_PATH$INCOMING, .enqueue=FALSE, serno=serno, queue="0")
        moveJob(j, MOTUS_PATH$PRIORITY)
    }
    motusLog("Sync server stopped")
    quit(save="no")
}
