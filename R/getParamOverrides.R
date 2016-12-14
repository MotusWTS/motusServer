#' Get the parameter overrides for a receiver and time or boot session.
#'
#' @param serno character scalar; serial number of receiver, e.g. "Lotek-123" or
#'     "SG-5133BBBK2972"
#'
#' @param monoBN integer scalar; boot session for which we want the overrides;
#' (ignored if \code{serno} is a Lotek receiver
#'
#' @param tsStart real scalar; starting timestamp for which we want the overrides;
#' (ignored if \code{serno} is a sensorgnome)
#'
#' @param progName program name for which the parameters are sought;
#' Default: "find_tags_motus"
#'
#' @return a character scalar of parameters, ready for the command line
#'
#' @note Overrides come from the paramOverrides table of the motus meta database.
#' As of 2016 Dec 14, this database is just copied from /sgm/paramOverrides.sqlite, but
#' eventually motus will provide user-editable fields for these.
#'
#' An override can be specified for either a whole project, or for a receiver.
#' In both cases, the override period can be specified as well.  A receiver-specific
#' override will override a project-wide override, if both are applicable.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getParamOverrides = function(serno, monoBN=NULL, tsStart=NA, progName="find_tags_motus") {

    meta = safeSQL(getMotusMetaDB())

    if (!is.null(monoBN)) {
        ## lookup the timestamp for the start of this boot session
        tsStart = sgTimeAtBoot(serno, monoBN)
    }

    ## lookup the projectID for the appropriate receiver deployment
    pid = meta("select projectID from recvDeps where serno=:serno and tsStart <= :tsStart
and (tsEnd is null or tsEnd > :tsStart) order by tsStart desc limit 1",
               serno=serno,
               tsStart = tsStart)[[1]]

    ## lookup project-wide overrides by date

    if (length(pid) > 0) {
        projOR = meta("select '--' || paramName || ' ' || paramVal from paramOverrides where projectID=:pid and progName=:progName
and tsStart <= :tsStart and (tsEnd is null or tsEnd > :tsStart) order by tsStart desc limit 1",
pid=pid,
progName=progName,
tsStart=tsStart)[[1]]
    } else {
        projOR = NULL
    }

    ## lookup receiver-specific overrides by date

    recvOR = meta("select '--' || paramName || ' ' || paramVal from paramOverrides where serno=:serno and progName=:progName
and tsStart <= :tsStart and (tsEnd is null or tsEnd > :tsStart) order by tsStart desc limit 1",
                  serno=serno,
                  progName=progName,
                  tsStart=tsStart)[[1]]

    ## Combine overrides, with any receiver-specific ones following
    ## and thus overriding the project-wide ones.

    allOR = c(projOR, recvOR)

    if (length(allOR) > 0)
        allOR = paste(allOR, collapse=" ")
    else
        allOR = ""

    meta(.CLOSE=TRUE)
    return(allOR)
}
