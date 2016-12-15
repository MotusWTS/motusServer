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
#' @note FIXME: we run all data from the receiver in a single go; we need
#' a batch concept for these receivers, if for no other reason than
#' to allow time/deployment-dependent parameter overrides.
#' see \link{https://github.com/jbrzusto/motusServer/issues/60}
#' For now, any project or receiver parameter override active
#' at the time the function is called will be used.
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

    ## get parameter overrides
    por = getParamOverrides(serno, tsStart=Sys.time())

    rv = ltFindTags(src, getMotusMetaDB(), par=paste(ltDefaultFindTagsParams, por))
    closeRecvSrc(src)
    jobLog(j, paste0("Got ", rv[2], " tag detections."))

    return(TRUE)
}
