#' run the tag finder on all files from a Lotek receiver
#'
#' Called by \code{\link{processServer}}. After running the tag
#' finder, queues a new subjob that exports data.
#'
#' @param j, the job.  It has these properties:
#' \enumerate{
#' \item serno: serial number of receiver; "Lotek-NNN"
#' \item tsStart: earliest timestamp of a detection in a file
#' with new data.  Not used at present, but might
#' allow for pause/resume later.
#' }
#'
#' @return
#'
#' @seealso \link{\code{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleLtFindtags = function(j) {

    serno = j$serno
    jobLog(j, paste0("Running tag finder on receiver ", serno))
    src = getRecvSrc(serno)
    rv = ltFindTags(serno, src, getMotusMetaDB())
    closeRecvSrc(src)
    jobLog(j, paste0("Got ", rv[2], " tag detections."))

    return(TRUE)
}
