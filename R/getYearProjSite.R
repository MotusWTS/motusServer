#' Get the project and site folders, given a year and receiver serial number.
#'
#' This is a deprecated function to help process data files in the
#' old sensorgnome YEAR/PROJECT/SITE hierarchy.  For each
#' \code{(serno, ts)} pair, it looks up the latest and project for the
#' receiver with serial number \code{serno} which is not later than
#' \code{ts}.
#'
#' @param serno character vector of serial numbers
#'
#' @param ts timestamp; recycled along \code{serno}
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

getYearProjSite = function(serno, ts) {
    serts = data_frame(serno=serno, ts=ts, year=as.integer(NA), proj=as.character(NA), site=as.character(NA))

    ## use a temporary database to do this as a join query
    con = dbConnect(RSQLite::SQLite(), ":memory:")
    sql = function(...) dbGetQuery(con, sprintf(...))

    sql("attach database '%s' as d", MOTUS_RECV_SERNO_DB)
    dbWriteTable(con, "serts", serts %>% as.data.frame, row.names=FALSE)

    ## left join trick to get latest row (largest tsHi) for each receiver
    res = sql("select t1.serno as serno, t1.ts as year, t2.Project as proj, t2.Site as site
    from serts as t1 left outer join d.map as t2 on t1.serno = t2.Serno and t1.ts >= t2.tsLo left outer join d.map as t3 on t2.Serno=t3.Serno and t3.tsLo > t2.tsLo where t1.ts >= t2.tsLo and t3.Serno is null")

    res$year = as.integer(year(structure(res$year, class=class(Sys.time()))))
    dbDisconnect(con)
    return(res)
}
