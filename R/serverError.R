#' Handle an error for the motus server.
#'
#' This function is installed as the top-level error handler by
#' \link{\code{server}}
#'
#' It records a stack dump to /sgm/errors and returns a summary error
#' message.
#'
#' @return nothing
#'
#' @export
#'
#' @note based on R's dump.frames()
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

serverError = function(...) {
    calls = sys.calls()
    last.dump = sys.frames()
    names(last.dump) = limitedLabels(calls)
    last.dump = last.dump[-length(last.dump)]
    attr(last.dump, "error.message") = e = geterrmessage()
    class(last.dump) = "dump.frames"
    out = paste0(makeQueuePath("dump", isdir=FALSE, dir=MOTUS_PATH$ERRORS, create=FALSE), ".rds")
    saveRDS(last.dump, out)
    motusLog("Error with call stack saved to %s:\n   %s", out, e)
}
