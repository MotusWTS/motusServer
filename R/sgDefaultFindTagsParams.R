#' default list of parameters for the tag finder
#'
#' These are:
#' \itemize{
#' \item   pulses_to_confirm        number of pulses required from a tag before its identity is treated as confirmed
#' \item   frequency_slop           kHz in allowed variation in offset frequency within a run
#' \item   min_dfreq                kHz; minimum allowed offset frequency
#' \item   max_dfreq                kHz; maximum allowed offset frequency
#' \item   pulse_slop               ms; maximum allowed slop in pulse timing within a burst
#' \item   burst_slop               ms; maximum allowed slop for a burst interval
#' \item   burst_slop_expansion     ms; amount by which burst slop is allowed to grow per missed burst
#' \item   use_events               use the events table in the tag database, so that tags are only sought while alive
#' \item   max_skipped_bursts       seconds; maximum amount of time between detections in a tag run
#' \item   default_freq             MHz, default antenna frequency, when not provided in input
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
        "--pulse_slop=1.5",
        "--burst_slop=4",
        "--burst_slop_expansion=1",
        "--use_events",
        "--max_skipped_bursts=20",
        "--default_freq=166.38"
        ),
        collapse = " ")
