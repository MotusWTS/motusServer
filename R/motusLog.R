#' Record messages to the motus main log.
#'
#' Works like sprintf, but sends output to the motus main log file,
#' after prepending the current date/time.  Output is followed by an
#' end-of-line.  If passed only a character vector, it is logged
#' with one item per line, with those after the first line indented.
#'
#' @param fmt character scalar \code{sprintf}-style formatting string
#' or character vector.
#'
#' @param ... any parameters required for \code{fmt}
#'
#' @return invisible(NULL)
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusLog = function(fmt, ...) {
    if (length(list(...)) == 0) {
        out = paste(fmt, collapse="   \n")
    } else {
        out = sprintf(fmt, ...)
    }
	
	# rotate the log file once per month
    tryCatch( {
		MOTUS_MAINLOG_NAME <- paste(MOTUS_MAINLOG_NAME_PREFIX, format(Sys.Date(), "%Y%m"), ".txt", sep="")
		if (MOTUS_MAINLOG_NAME !=  summary(MOTUS_MAINLOG)$description) {
			close(MOTUS_MAINLOG)
			MOTUS_MAINLOG <<- file(newfile, "a")
		}
    }, error = function(e) {
        MOTUS_MAINLOG <<- stdout()
    })

    cat( format(Sys.time(), MOTUS_LOG_TIME_FORMAT),
        ": ",
        out,
        "\n",
        sep="",
        file = MOTUS_MAINLOG
        )
    invisible(NULL)
}

