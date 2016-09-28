#' Get the project and site folders, given a year and receiver serial number.
#'
#' This is a deprecated function to help process data files in the old
#' sensorgnome YEAR/PROJECT/SITE hierarchy.  For each \code{(serno,
#' ts)} pair, it looks up the latest project and site for the receiver
#' with serial number \code{serno} which is not later than \code{ts}.
#' If no site is found for the given valid timestamp, boot numbers are
#' used, if possible.
#'
#' @param serno character vector of serial numbers
#'
#' @param ts timestamp; recycled along \code{serno}
#'
#' @param bootnum boot session count; default: NULL meaning no bootnums
#' available.
#' 
#' @return a data.frame with these columns:
#' \itemize{
#' \item serno receiver serial number
#' \item year integer
#' \item proj project folder in /SG/year, or NA if none found
#' \item site site subfolder in /SG/year/proj, or NA if none found
#' }
#'
#' 
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getYearProjSite = function(serno, ts, bootnum = NULL) {
    serts = data_frame(serno   = serno,
                       ts      = ts,
                       bootnum = if (is.null(bootnum)) as.integer(NA) else bootnum,
                       year    = as.integer(NA),
                       proj    = as.character(NA),
                       site    = as.character(NA)
                       )

    ## use a temporary database to do this as a join query
    con = dbConnect(RSQLite::SQLite(), ":memory:")
    sql = function(...) dbGetQuery(con, sprintf(...))

    sql("attach database '%s' as d", MOTUS_RECV_SERNO_DB)
    dbWriteTable(con, "serts", serts %>% as.data.frame, row.names=FALSE)

    ## get latest row (largest tsHi) that is still no later than ts for each receiver 
    sql("create table res as select t1.serno as serno, t1.ts as year, t2.Project as proj, t2.Site as site, t2.tsLo as tsLo, t2.tsHi as tsHi   from serts as t1 left outer join d.map as t2 on t1.serno = t2.Serno and t2.tsLo = (select max(t3.tsLo) from d.map as t3 where t3.Serno=t2.Serno and t3.tsLo <= t1.ts)")

    res = sql("select * from res")

    res$year = as.integer(year(structure(res$year, class=class(Sys.time()))))

    bad = which(is.na(res$site))
    if (length(bad) > 0 && ! is.null(bootnum)) {
        ## for each file with no site, use the year/proj/site with the largest bootnum
        ## that is <= the file's
        ## do this by a step mapping from bootnum to year/project/site entry
        goodres = subset(res, !is.na(site))
        goodres = goodres[order(goodres$bootnum),]
        map = approxfun(goodres$bootnum, 1:nrow(goodres), method="constant", f=0, rule=2)
        res[bad, c("year", "proj", "site")] = res[map(res$bootnum[bad]), c("year", "proj", "site")]
    }
    dbDisconnect(con)
    return(res)
}
