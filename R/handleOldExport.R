#' export data the 'old' (pre-motus) way.
#'
#' @details We generate Year/Proj/Site plots for the receiver, showing tag
#' detections and receiver status, then upload these to the user's wiki
#' page at sensorgnome.org
#'
#' @param j the job, with these fields:
#' \itemize{
#' \item serno - the receiver serial number
#' \item monoBN - the range of receiver bootnums; NULL for Lotek receivers.
#' \item ts - the approximate range of timestamps; the first is guaranteed to
#' be the minimum ts of any new data, but the last is a lower bound on the
#' latest ts; the lower bound is accurate to ~ 1 hour for SGs, but may be
#' wildly off for Lotek receivers.
#' }
#'
#' @return TRUE
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleOldExport = function(j) {
    return (TRUE)
}
