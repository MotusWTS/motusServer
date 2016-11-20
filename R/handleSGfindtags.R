#' run the tag finder on one sensorgnome boot session, in the new style.
#'
#' Called by \code{\link{server}}.
#'
#' Runs the new tag finder for one boot session of a single SG.
#' The files for that boot session have already been merged into
#' the DB for that receiver.
#'
#' @param j the job, with these properties:
#' \itemize{
#' \item serno serial number of receiver (including leading 'SG-')
#' \item monoBN monotonic boot session number
#' \item boolean TRUE or FALSE; can the tag finder be run with \code{--resume}?
#' }
#'
#' @return TRUE on success, or FALSE if the tag finder has an error.
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleSGfindtags = function(j) {

    serno = j$serno

    jobLog(j, paste0("Running tag finder on receiver ", serno, " boot session ", j$monoBN, if (j$canResume) " (resumed)"))

    ## lock this receiver's DB.  If we can't, then sleep for 10 seconds and try again.

    while(! lockReceiver(serno)) {
        ## FIXME: we should probably return NA immediately, and have processServer re-queue the job at the end of the queue
        Sys.sleep(10)
    }

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockReceiver(serno, FALSE))

    ## run the tag finder
    tryCatch({
        rv = sgFindTags(sgRecvSrc(serno), getMotusMetaDB(), resume=j$canResume, mbn=j$monoBN)
    }, error = function(e) {
        jobLog(j, paste(as.character(e), collapse="   \n"))
        rv = NULL
    })

    if (is.null(rv))
        return(FALSE)

    jobLog(j, paste0("Got ", rv$numHits, " detections."))
    return(TRUE)
}
