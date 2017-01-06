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
        serno = basename(feed())    ## this might might wait a long time
        serno = gsub("[^-[:alnum:]]", "", serno, perl=TRUE) ## replace dangerous characters
        if (tracing)
            browser()

        ## the files placed in /sgm/sync are empty; their names are the serial number
        ## of an attached receiver.

        repoDir = file.path(MOTUS_PATH$FILE_REPO, serno)
        if (!file.exists(repoDir))
            dir.create(repoDir)

        ## get the port number
        port = ServerDB("select tunnelport from receivers where serno=:serno", serno=serno)[[1]]

        ## use rsync to grab files into the file repo, and return a list of their names
        ## relative to repoDir; returned as a '\n'-delimited string
        fileList = safeSys(sprintf("rsync --dry-run --rsync-path='ionice -c 3 nice -n 12 rsync' --size-only --out-format '%%n' -r -e 'sshpass -p bone ssh -oStrictHostKeyChecking=no -p %d' bone@localhost:/media/*/SGdata/* /sgm/file_repo/%s/", port, serno), quote=FALSE)

        newFiles = file.path(repoDir, strsplit(fileList, "\n", fixed=TRUE)[[1]])

        ## queue a job to handle all the changed files
        j = newJob("newFiles", .parentPath=MOTUS_PATH$INCOMING, replyTo=MOTUS_ADMIN_EMAIL, .enqueue=FALSE)
        newdir = file.path(jobPath(j), "sync")
        dir.create(newdir)

        file.symlink(fileList, file.path(newdir, basename(fileList)))
        moveJob(j, MOTUS_PATH$PRIORITY)

        cat("Queued", length(newFiles), "files from attached receiver", serno, " into priority queue\n")
    }
    motusLog("Sync server stopped")
    quit(save="no")
}
