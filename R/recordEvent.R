#' record a processing event in the history table of the motus transfer database
#'
#' Recorded events are used to generate history pages on the wiki.
#'
#' @param event - short character scalar giving type of event; c("CLEAR", "MERGE", "FIND")
#'
#' @param origin - character scalar describing source of event; e.g. "data email from stuart@bsc-eoc.org", "user command on sensorgnome.org"
#'
#' @param serno - character scalar giving full serial number of device involved, if any. e.g. "SG-3214BBBK1512"
#'
#' @param exitCode - integer scalar giving exit code of processing; 0 means success; otherwise an error number. Default: 0.
#'
#' @param errorMsg - character scalar giving error message, if any.  Default: NULL
#'
#' @param URLs - character vector giving URLs of any output files posted to website
#'
#' @param URLlabels - character vector giving descriptive label (e.g. filename) for each URL
#'
#' @return no return value.  Side effect: a record is added to the \code{history} table in the motus transfer database
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

recordEvent = function(event = c("MERGE", "FINDTAGS", "CLEAN", "COMPAREOLDNEW","PLOT"), origin, serno = "", exitCode = 0, errorMsg = "", URLs = "", URLlabels = "") {
    event = match.arg(event)

    mdb = openMotusDB()
    ## sanitize inputs
    for (n in c("origin", "serno", "errorMsg", "URLs", "URLlabels"))
        assign(n, gsub("'", "''", get(n)))

    options(digits=14)
    dbGetQuery(mdb$con, sprintf("insert into history (event, origin, serno, exitCode, errorMsg, outputURLs, outputInfo, ts) values ('%s', '%s', '%s', %d, '%s', '%s', '%s', %.3f)",
                                event,
                                origin,
                                serno,
                                as.integer(exitCode),
                                errorMsg,
                                paste(URLs, collapse="^"),
                                paste(URLlabels, collapse="^"),
                                as.numeric(Sys.time())
                                )
               )
    rm(mdb)
}
