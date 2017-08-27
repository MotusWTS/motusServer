#' Load-time initialization code for motus package.
#'
#' Set up things so the motus package works:
#' \itemize{
#' \item set numeric output precision to 14 digits, for timestamp formatting
#' \item secrets load credentials for accessing databases and servers
#' \item open log file for output
#' \item open the server DB
#' }
#'
#' @return return invisible(NULL)
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
.onLoad = function(...) {

    options(digits=14)

    if (! motusLoadSecrets(quiet=TRUE, "~/.secrets/motusSecrets")) {
        MOTUS_SECRETS <<- new.env(emptyenv())
        makeActiveBinding(
            'key',
            function(x) {
                stop(call. = FALSE,
                     "This function requires motus credentials.\nUse motusLoadSecrets() to load them.")
            }, MOTUS_SECRETS
        )
    }

    tryCatch( {
        MOTUS_MAINLOG <<- file(file.path(MOTUS_PATH$LOGS, MOTUS_MAINLOG_NAME), "a")
    }, error = function(e) {
        MOTUS_MAINLOG <<- stdout()
    })

    invisible(NULL)
}
