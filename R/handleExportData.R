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
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleExportData = function(j) {
    serno = j$serno
    lockSymbol(serno)

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockSymbol(serno, lock=FALSE))

    src = getRecvSrc(serno)
    pushToMotus(src)
    closeRecvSrc(src)
    jobLog(j, paste("Pushed new batches from", serno, "to motus."))
    return (TRUE)
}
