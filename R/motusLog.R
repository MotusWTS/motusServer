#' Record messages to the motus main log.
#'
#' Works like sprintf, but sends output to the motus main log file,
#' after prepending the current date/time.  Output is followed by an
#' end-of-line.
#'
#' @param fmt character scalar \code{sprintf}-style formatting string
#'
#' @param ... any parameters required for \code{fmt}
#'
#' @return invisible(NULL)
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusLog = function(fmt, ...) {
    cat(sprintf(
        paste0("%s:", fmt),
        format(Sys.time(), MOTUS_LOG_TIME_FORMAT),
        ...),
        "\n",
        file = MOTUS_MAINLOG
        )
    invisible(NULL)
}

