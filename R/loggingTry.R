#' Try evaluate expression, logging the call stack in case of an error.
#'
#' This function wraps handlers called by \link{\code{server}}.  When
#' an error occurs, the timestamped stack dump is saved in
#' \code{MOTUS_PATH$errors}
#'
#' @param expr expression to evaluate
#' 
#' @return value of \code{expr}
#'
#' @export
#'
#' @note based on R's \code{util::dump.frames()} and \code{tools:::.try_quietly()}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

loggingTry = function (expr) 
{
    tryCatch(
        withRestarts(
            withCallingHandlers(expr,
                                error = function(e) invokeRestart( "gripe", e, sys.calls(), sys.frames())
                                ),
            gripe = function(e, calls, frames) {
                names(frames) = limitedLabels(calls)
                n = length(sys.calls())
                frames = frames[-seq.int(length.out = n - 1L)]
                frames = rev(frames)[-c(1L, 2L)]
                attr(frames, "error.message") = e
                class(frames) = "dump.frames"
                out = paste0(makeQueuePath("dump", isdir=FALSE, dir=MOTUS_PATH$ERRORS, create=FALSE), ".rds")
                saveRDS(frames, out)
                motusLog("Error with call stack saved to %s:\n   %s", out, e)
           }),
        error = identity
    )
}
