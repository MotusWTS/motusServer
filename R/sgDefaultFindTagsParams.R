#' default list of parameters for the tag finder
#'
#' These are:
#' \itemize{
#' \item   pulses_to_confirm = 8       number of pulses required from a tag before its identity is treated as confirmed
#' \item   frequency_slop    = 0.5     kHz in allowed variation in offset frequency within a run
#' \item   min_dfreq         = 0       kHz; minimum allowed offset frequency
#' \item   max_dfreq         = 12      kHz; maximum allowed offset frequency
#' \item   clock_fuzz        = 30      parts per million; maximum discrepancy between tag and receiver clock
#' \item   use_events                  use the events table in the tag database, so that tags are only sought while alive
#' \item   max_skipped_time  = 200     seconds; maximum amount of time between detections in a tag run
#' \item   default_freq      = 166.38  MHz, default antenna frequency, when not provided in input
#'}
#' 
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgDefaultFindTagsParams =
    paste(c(
        "--pulses_to_confirm=8",
        "--frequency_slop=0.5",
        "--min_dfreq=0",
        "--max_dfreq=12",
        "--clock_fuzz=30",
        "--use_events",
        "--max_skipped_time=200",
        "--default_freq=166.38"
        ),
        collapse = " ")