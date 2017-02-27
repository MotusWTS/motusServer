#' Get project and site names, given receiver serial numbers and timeranges
#'
#' This is meant to provide project and site labels for plots and summary files.
#' For each receiver in the input, all deployments that overlap the specified
#' time range are returned.
#'
#' @param serno character vector of serial numbers
#'
#' @param tsLo numeric vector of start times
#'
#' @param tsHi numeric vector of end times
#'
#' @return a data.frame with these columns:
#' \itemize{
#' \item serno receiver serial number
#' \item year integer year deployment began
#' \item proj name of project
#' \item site name of receiver deployment
#' \item tsStart timestamp at which this deployment begins
#' \item tsEnd timestamp at which this deployment ends
#' }
#'
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getYearProjSite = function(serno, tsLo, tsHi) {

    ## convert NULL to NA for data_frame, which can't handle former

    serts = data_frame(serno   = serno,
                       tsLo    = tsLo,
                       tsHi    = tsHi,
                       year    = as.integer(NA),
                       proj    = as.character(NA),
                       site    = as.character(NA),
                       tsStart = NA,
                       tsEnd   = NA
                       )

    ## use a temporary database to do this as a join query
    meta = safeSQL(getMotusMetaDB())

    ## look up sites by serial number and timestamp

    dbWriteTable(meta$con, "temp.serts", serts %>% as.data.frame, row.names=FALSE)

    ## get latest row (largest tsHi) that is still no later than ts for each receiver
    #### old version allowing for missing tsStart but valid tsEnd:
    #### rv = meta(sprintf("select t1.serno as serno, 0 as year, t4.label as proj, t2.name as site, (t2.tsStart * (t2.tsStart >= %14f) + (t2.tsEnd - 6 * 30 * 24 * 3600) * (t2.tsStart < %14f)) as tsStart from temp.serts as t1 left outer join recvDeps as t2 on t1.serno = t2.serno and t2.tsStart = (select max(t3.tsStart) from recvDeps as t3 where t3.serno=t2.serno and t3.tsStart <= t1.tsLo) left join projs as t4 on t2.projectID=t4.id", MOTUS_SG_EPOCH, MOTUS_SG_EPOCH))

    rv = meta(sprintf("select t1.serno as serno, 0 as year, t3.label as proj, t2.name as site, t2.tsStart as tsStart, t2.tsEnd as tsEnd from temp.serts as t1 left outer join recvDeps as t2 on t1.serno = t2.serno and t2.tsStart <= t1.tsHi and (t2.tsEnd is null or t2.tsEnd >= t1.tsLo) left join projs as t3 on t2.projectID=t3.id", MOTUS_SG_EPOCH, MOTUS_SG_EPOCH))

    ## for some reason, the above leads to a character column if there's an NA anywhere in it
    rv$tsStart = as.numeric(rv$tsStart)
    rv$year = as.integer(year(structure(rv$tsStart, class=class(Sys.time()))))

    meta(.CLOSE=TRUE)
    return(rv)
}
