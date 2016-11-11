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

    jobLog(paste0("Running tag finder on receiver ", j$serno))
    rv = ltFindTags(sgRecvSrc(j$serno), getMotusMetaDB())
    jobLog(paste0("Got ", rv, " tag detections."))

    return(TRUE)
}
