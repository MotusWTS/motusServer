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
#' If only exporting, then export from the latest deployment record
#' that is not later than \code{monoBN[1]}.
#'
#' \item ts real vector of length 1 or 2; the start (and possibly end)
#' timestamp of boot sessions to run.  Ignored for an SG. If not
#' specified for a Lotek receiver, exports all data.  Otherwise, exports
#' data only in the specified period (if length is 2) or starting
#' at the specified timestamp (if length is 1)
#'
#' \item exportOnly logical scalar; if TRUE, skip running the tagfinder
#'
#' \item cleanup logical scalar; if TRUE, delete all hits, runs,
#' batches before re-running.  Ignored (and treated as FALSE) if
#' monoBN is specified.  i.e. cleanup can only be specified for a
#' full re-run.
#'
#' \item [optional] paramOverrides; if present, must be a string scalar
#' specifying parameters to the tag finder, which will be appended to
#' any default and registered override values; thus, parameter values specified
#' here will override those from other sources.  This item is handled
#' in \code{\link{handleSGfindtags}} or \code{\link{handleLtFindtags}}
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
    ts = j$ts

    if (length(monoBN) > 0)
        cleanup = FALSE

    isLotek = grepl("^Lotek", serno, perl=TRUE)

    ## Lock the receiver; this is really only needed for cleanup and
    ## selecting existing boot sessions, but easiest to always do.

    lockSymbol(serno)

    ## make sure we unlock the receiver DB when this function exits,
    ## even on error.  NB: the runMotusProcessServer script also drops
    ## any locks held by a given processServer after the latter exits.

    on.exit(lockSymbol(serno, lock=FALSE))

    if (cleanup) {
        src = getRecvSrc(serno)
        cleanup(src, TRUE)
        closeRecvSrc(src)
    }

    if (isLotek) {
        ## get last 4 years, if no timestamps specified
        if (is.null(ts)) {
            now = as.numeric(Sys.time())
            ts = c(now - 4 * 365.25 * 24 * 60 * 60, now)
        }
    } else {
        ## for an SG, get all boot sessions within the range, or all if null
        ## We only do this if we'll be running the tag finder, as
        src = getRecvSrc(serno)
        allBN = dbGetQuery(src$con, "select distinct monoBN from files order by monoBN")[[1]]
        if (length(monoBN) == 0) {
            monoBN = allBN
        } else {
            ## subset of the sequence monoBN[1]:monoBN[2] for which we have files
            monoBN = allBN[allBN >= monoBN[1] & allBN <= monoBN[2]]
        }
        closeRecvSrc(src)
    }

    ## queue runs of a receiver (or some boot session(s), for SGs)

    if (! exportOnly) {
        if (isLotek) {
            newSubJob(j, "LtFindtags", serno=serno, ts=ts)
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
    if (isLotek)
        newSubJob(topJob(j), "plotData", serno=serno, ts=range(ts))
    else
        newSubJob(topJob(j), "plotData", serno=serno, monoBN=range(monoBN))

    return(TRUE)
}
