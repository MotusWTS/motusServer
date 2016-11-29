#' re-run data from a receiver
#'
#' Called by \code{\link{processServer}}
#'
#' @details re-runs the tagfinder for a receiver, possibly limiting the
#' re-run to one or more boot sessions (for SGs).
#'
#' @param j the job with these items:
#'
#' \itemize{
#'
#' \item serno character scalar; the receiver serial number
#'
#' \item monoBN integer vector of length 2; the range of receiver boot
#' sessions to run; If not specified, then for an SG receiver, all
#' boot sessions are rerun.  Ignored for Lotek receivers.
#'
#' \item exportOnly logical scalar; if TRUE, skip running the tagfinder
#'
#' \item cleanup logical scalar; if TRUE, delete all hits, runs,
#' batches before re-running.  Ignored (and treated as FALSE) if
#' monoBN is specified.  i.e. cleanup can only be specified for a
#' full re-run.
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
    exportOnly = j$exportOnly
    cleanup = j$cleanup
    if (length(monoBN) > 0)
        cleanup = FALSE

    isLotek = grepl("^Lotek", serno, perl=TRUE)

    ## Lock the receiver; this is really only needed for cleanup and
    ## selecting existing boot sessions, but easiest to always do.

    while(! lockReceiver(serno)) {
        ## FIXME: we should probably return NA immediately, and have
        ## processServer re-queue the job at the end of the queue
        Sys.sleep(10)
    }

    ## make sure we unlock the receiver DB when this function exits,
    ## even on error.  NB: the runMotusProcessServer script also drops
    ## any locks held by a given processServer after the latter exits.

    on.exit(lockReceiver(serno, FALSE))

    if (cleanup) {
        cleanup(sgRecvSrc(serno), TRUE)
    }

    ## for an SG, get all boot sessions within the range, or all if null
    if (! isLotek) {
        src = sgRecvSrc(serno)
        allBN = dbGetQuery(src$con, "select distinct monoBN from files order by monoBN")[[1]]
        if (length(monoBN) == 0) {
            monoBN = allBN
        } else {
            ## subset of the sequence monoBN[1]:monoBN[2] for which we have files
            monoBN = allBN[allBN >= monoBN[1] & allBN <= monoBN[2]]
        }
        dbDisconnect(src$con)
    }

    ## queue runs of a receiver (or some boot session(s), for SGs)

    if (! exportOnly) {
        if (isLotek) {
            newSubJob(j, "LtFindtags", serno=serno)
        } else {
            for (mbn in monoBN) {
                newSubJob(j, "SGfindtags",
                          serno = serno,
                          monoBN = mbn,
                          canResume = FALSE
                          )
            }
        }
    }

    ## queue data export

    newSubJob(topJob(j), "exportData", serno=serno)
    newSubJob(topJob(j), "oldExport", serno=serno, monoBN=range(monoBN))

    return(TRUE)
}
