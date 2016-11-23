#' rerun data from a receiver
#'
#' Called by \code{\link{processServer}}
#'
#' @details reruns the tagfinder for a receiver, possibly limiting the
#' re-run to one or more boot sessions (for SGs).
#'
#' @param j the job with these items:
#'
#' \itemize{
#'
#' \item serno character scalar; the receiver serial number
#'
#' \item monoBN integer vector of length 2; the range of receiver boot
#' sessions to run; NULL for Lotek receivers.  If not specified for an
#' SG receiver, then all boot sessions are rerun.
#'
#' }
#'
#' @return TRUE
#'
#' @seealso \link{\code{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleRerunReceiver = function(j) {
    serno = j$serno
    monoBN = j$monoBN

    isLotek = grepl("^Lotek", serno, perl=TRUE)

    while(! lockReceiver(serno)) {
        ## FIXME: we should probably return NA immediately, and have processServer re-queue the job at the end of the queue
        Sys.sleep(10)
    }

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockReceiver(serno, FALSE))

    ## function to queue a run of a receiver boot session, and export of its data

    if (isLotek) {
        newSubJob(j, "LtFindtags", serno=serno)
    } else {
        ## get all boot sessions within the range, or all if null
        src = sgRecvSrc(serno)
        allBN = dbGetQuery(src$con, "select distinct monoBN from files order by monoBN")[[1]]
        if (is.null(monoBN)) {
            monoBN = allBN
        } else {
            ## subset of the sequence monoBN[1]:monoBN[2] for which we have files
            monoBN = allBN[allBN >= monoBN[1] & allBN <= monoBN[2]]
        }
        for (mbn in monoBN) {
            newSubJob(j, "SGfindtags",
                      serno = serno,
                      monoBN = mbn,
                      canResume = FALSE
                      )
        }
    }
    newSubJob(topJob(j), "exportData", serno=serno)
    newSubJob(topJob(j), "oldExport", serno=serno, monoBN=range(monoBN))

    return(TRUE)
}
