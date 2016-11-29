#' Close the src_sqlite for a receiver database.
#'
#' receiver database files are stored in a single directory, and
#' have names like "SG-XXXXBBBKYYYY.motus" or "Lotek-NNNNN.motus"
#'
#' @param src dplyr::src_sqlite as returned by \link{\code{getRecvSrc()}}
#'
#' @return no return value.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

closeRecvSrc = function(src) {
    dbDisconnect(src$con)
}
