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
#' @details the start time is typically \code{fixedBy + tsLow} for records in the
#' receiver's timeFixes table.  This needs to be made explicit; see:
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
    ## ...(MN))", then join that to the timeFixes table for this
    ## receiver.  We group by t1.monoBN in case there's more than one
    ## timeFix for a given bootnum, and in that case use the minimum.
    ## The 'left' join ensures we get NA when the given monoBN slot has
    ## no corresponding entry in timeFixes

    rv = as.numeric(
        sql(paste0("with tmpbn(monoBN) as ( values ", paste0("(", monoBN, ")", collapse=","), ")
 select min(t2.fixedBy + t2.tsLow) as ts from tmpbn as t1 left join timeFixes as t2
 on t1.monoBN=t2.monoBN group by t1.monoBN")) [[1]])

    sql(.CLOSE=TRUE)
    return(rv)
}
