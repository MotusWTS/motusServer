#' Ensure we have monotonic boot numbers for a receiver database.
#'
#' Sensorgnomes are supposed to know how many times they've been booted,
#' and record this \emph{bootnum} in the name of each file they write.
#' One use of this information is to position batches of files in real
#' time if they were recorded during a boot session when the SG failed
#' to set its clock to GPS time.  These files will then appear to have
#' been written in the year 2000.  If the boot session before or after
#' the problematic one \emph{is} correctly dated, that lets us
#' bracket the time interval in which the undated boot session must belong.
#'
#' Unfortunately, this scheme has failed in a few situations:
#' \itemize{
#'
#'   \item on beaglebone whites (BBW) where the SD card is changed
#'   between boot sessions.  The boot count is stored on the SD card
#'   (there is no internal storage on the BBW), and there's no
#'   mechanism in place to set the boot count correctly when a new
#'   card is used.
#'
#'   \item on beaglebone blacks using a software image from some time
#'   in 2014(?) when the boot count was not updated correctly if it
#'   was at 2; in that case it is stuck at 2.
#' 
#'   \item on beaglebone blacks re-imaged using a software image that
#'   did not preserve the boot count on the target BBBK.  (I don't
#'   remember exactly which version(s) were affected).
#'
#' }
#'
#' This function attempts to generate a monotonic sequence of boot numbers
#' and 
#' @param src dplyr:src_sqlite open to an existing receiver database
#'
#' @note If err is not NA for a file, then other fields for that file
#'     might not be set appropriately in the return value.
#' 
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureMonoBN = function(src) {


    ### TODO
}
