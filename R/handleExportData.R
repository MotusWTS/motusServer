#' push newly generated data to motus transfer tables
#'
#' Any new batches for this receiver, and their associated runs, hits,
#' and GPS fixes are added to motus transfer tables.
#'
#' @param j the job, with these fields:
#' \itemize{
#' \item serno - the receiver serial number
#' }
#'
#' @return TRUE
#'
#' @export
#'
#' @note if the top level job has a TRUE value for parameter
#'     \code{isTesting}, then the batches transferred will be given
#'     \code{status = -1}, rather than the usual {status = 1}.  This tells
#'     \code{\link{dataServer()}} not to return records for such
#'     batches unless explicitly requested to by the \code{includeTesting} parameter.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleExportData = function(j) {
    serno = j$serno
    lockSymbol(serno)

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockSymbol(serno, lock=FALSE))

    batchStatus = if (isTRUE(topJob(j)$isTesting)) -1 else 1
    src = getRecvSrc(serno)
    pushToMotus(src, batchStatus)
    closeRecvSrc(src)
    jobLog(j, paste("Pushed new batches from", serno, "to motus."))
    return (TRUE)
}
