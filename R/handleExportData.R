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
    pushToMotus(sgRecvSrc(j$serno))
    return (TRUE)
}
