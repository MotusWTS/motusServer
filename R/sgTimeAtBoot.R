#' Get start times for boot sessions for a sensorgnome.
#'
#' @param serno character scalar; serial number of sensorgnome, e.g. "SG-5133BBBK2972"
#'
#' @param monoBN integer vector; boot session(s) for which boot times are desired.
#'
#' @return real vector of timestamps, one per item of \code{monoBN}.  NA for any
#' slot where the boot time could not be estimated; e.g. because the receiver
#' did not get a GPS fix.
#'
#' @details the start time is taken as the first valid timestamp of
#'     files from that boot session.  In most situations, the GPS sets
#'     a sensorgnome's clock shortly after boot, so the estimate will
#'     be some few minutes later than the true boot time.  Where
#'     possible, we correct for the timespan during which the SG was
#'     producing pre-GPS-timestamped files in that boot session.
#'
#' This procedure needs to be made explicit in upstream processing; see:
#' \link{https://github.com/jbrzusto/find_tags/issues/12}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgTimeAtBoot = function(serno, monoBN) {
    if (grepl("^Lotek-", serno))
        stop ("sgTimeAtBoot() not implemented for Lotek receivers")

    sql = safeSQL(getRecvSrc(serno)$con)

    ## Use a common table expression to import the monoBN values into
    ## a temporary table using a clause like "(values (M1), (M2),
    ## ...(MN))", then join that to the files table, where we look for
    ## the earliest valid file timestamp for each boot session

    rv = as.numeric(
        sql(paste0("with tmpbn(monoBN) as ( values ", paste0("(", monoBN, ")", collapse=","), ")
 select t2.ts as ts from tmpbn as t1 left join (select monoBN, min(ts) as ts from files where ts >= ", MOTUS_SG_EPOCH, " group by monoBN) as t2
 on t1.monoBN=t2.monoBN")) [[1]])

    ## as a minimum correction, look at the span of time among pre-GPS timestamped files
    ## from the same boot session, if there are at least two

    preGPS = sql(paste0("with tmpbn(monoBN) as ( values ", paste0("(", monoBN, ")", collapse=","), ")
 select t2.tsLo, t2.tsHi from tmpbn as t1 left join (select monoBN, min(ts) as tsLo, max(ts)
as tsHi from files where ts < ", MOTUS_SG_EPOCH, " group by monoBN) as t2 on t1.monoBN=t2.monoBN"))

    span = as.numeric(preGPS$tsHi) - as.numeric(preGPS$tsLo)
    span[is.na(span)] = 0

    rv = rv - span

    sql(.CLOSE=TRUE)
    return(rv)
}
