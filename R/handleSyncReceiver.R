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

    repoDir = file.path(MOTUS_PATH$FILE_REPO, serno)
    if (!file.exists(repoDir))
        dir.create(repoDir)

    ## get the port number (drop the "SG-" prefix from serno)
    port = ServerDB("select tunnelport from remote.receivers where serno=:serno", serno=substring(serno, 4))[[1]]

    ## ignore request if there's no tunnel port known for this serial number
    if (! isTRUE(port > 0)) {
        jobLog(j, paste0("No tunnel port for receiver ", serno), summary=TRUE)
        return(FALSE)
    }

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
    rv = safeSys(sprintf("rsync --rsync-path='ionice -c 2 -n 7 nice -n 10 rsync' --size-only --out-format '%%n' -r -e 'sshpass -p bone ssh -oStrictHostKeyChecking=no -p %d' --filter='+ **/' --filter='+ **%s**' --filter='- **' bone@localhost:/media/*/SGdata/ /sgm/file_repo/%s/", port, substring(serno, 4), serno), quote=FALSE, minErrorCode=100, splitOutput=TRUE)

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
