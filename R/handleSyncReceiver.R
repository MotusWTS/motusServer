#' sync from an attached receiver, processing any new data
#'
#' Called by \code{\link{syncServer}}
#'
#' @details grabs any new data from the attached receiver, and
#' re-runs the tagfinder
#'
#' @param j the job with these items:
#'
#' \itemize{
#'
#' \item serno character scalar; the receiver serial number
#' \item method; method for reaching the receiver.  So far, this
#' must be an integer, representing a tunnel port number (i.e.
#' number of a port on localhost that has been mapped back
#' to the ssh port (22) on the remote SG, typically via
#' the server at sensorgnome.org  Tunnel port numbers start
#' at 40000 and do not exceed 65535.
#' \item motusUserID integer scalar; the ID of the motus user
#' who registered the receiver for remote sync
#' [only used by \code{\link{handleSGfindtags}} and \code{\link{handleLtFindtags}}]
#' \item motusProjectID integer scalar; the ID of the motus
#' project specified when the receiver was registered for
#' remote sync [only used by \code{\link{handleSGfindtags}} and \code{\link{handleLtFindtags}}]
#'
#' }
#'
#' @return TRUE
#'
#' @seealso \link{\code{syncServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleSyncReceiver = function(j) {
    serno = j$serno
    port = as.integer(j$method)
    if (is.na(port)|| port < 40000 || port > 65535) {
        jobLog(j, paste0("Invalid method for syncing receiver ", serno, ": ", j$method))
        return(FALSE)
    }
    repoDir = file.path(MOTUS_PATH$FILE_REPO, serno)
    if (!file.exists(repoDir))
        dir.create(repoDir)

    ## lock the receiver

    lockSymbol(serno)

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockSymbol(serno, lock=FALSE))

    ## use rsync to grab files into the file repo, and return a list of their names
    ## relative to repoDir; returned as a '\n'-delimited string
    ## we ignore errors, and user whatever list of files is returned
    ## Note:  we only pull files which include the bare (without "SG-") serial number
    ## of the receiver.  Otherwise, we might grab files on a card or memory stick which
    ## had files from other receivers.
    rv = safeSys(sprintf("rsync --rsync-path='ionice -c 2 -n 7 nice -n 10 rsync' --size-only --out-format '%%n' -r -e 'sshpass -p bone ssh -oStrictHostKeyChecking=no -p %d' --filter='+ **/' --filter='+ **%s**' --filter='- **' bone@localhost:/media/*/SGdata/ /sgm/file_repo/%s/", port, substring(serno, 4, 15), serno), quote=FALSE, minErrorCode=1000, splitOutput=TRUE)

    ## remove directories, else these will be traversed, leading to double
    ## listings of files
    rv = grep("/$", rv, perl=TRUE, invert=TRUE, value=TRUE)
    if (! isTRUE(length(rv) > 0)) {
        jobLog(j, paste0("No new files obtained for receiver ", serno), summary=TRUE)
        return(FALSE)
    }

    newFiles = file.path(repoDir, rv)

    nj = newSubJob(j, "newFiles")

    ## queue a job to handle all the changed files
    newDir = file.path(jobPath(nj), "sync")
    dir.create(newDir)

    file.symlink(newFiles, file.path(newDir, basename(newFiles)))

    jobLog(j, paste("Queued", length(newFiles), "files from attached receiver", serno), summary=TRUE)
    if (length(newFiles) > 6) {
        newFiles = c(head(newFiles, 3), "...", tail(newFiles, 3))
    }
    jobLog(j, paste0("Queued files:\n", paste("   ", newFiles, collapse="\n")))
    return (TRUE)
}
