#' record a processing event in the history table of the motus transfer database
#'
#' Recorded events are used to generate history pages on the wiki.
#'
#' @param event - short character scalar giving type of event; c("CLEAR", "MERGE", "FIND")
#'
#' @param origin - character scalar describing source of event; e.g. "data email from stuart@bsc-eoc.org", "user command on sensorgnome.org"
#'
#' @param motusDeviceID - integer scalar giving ID of device involved; e.g. if it's data for a receiver. Default:  NULL
#'
#' @param exitCode - integer scalar giving exit code of processing; 0 means success; otherwise an error number. Default: 0.
#'
#' @param errorMsg - character scalar giving error message, if any.  Default: NULL
#'
#' @return no return value.  Side effect: a record is added to the \code{history} table in the motus transfer database
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

recordEvent = function(event = c("MERGE", "FIND", "CLEAR"), origin, motusDeviceID = NULL, exitCode = 0, errorMsg = "") {
    event = match.arg(event)

    mdb = openMotusDB()
    ## sanitize inputs
    for (n in c("origin", "errorMsg"))
        assign(n, gsub("'", "\\'", get(n)))

    dbGetQuery(mdb$con, sprintf("insert into history (event, origin, motusDeviceID, exitCode, errorMsg) values ('%s', '%s', %d, %d, '%s')",
                                event,
                                origin,
                                if(! is.null(motusDeviceID)) as.integer(motusDeviceID) else NULL,
                                as.integer(exitCode),
                                errorMsg))
    rm(mdb)
}
