#' Get the project and site folders, given a year and receiver serial number.
#'
#' This is a deprecated function to help process data files in the old
#' sensorgnome YEAR/PROJECT/SITE hierarchy.  Sites are looked up
#' by bootnum for sensorgnomes, and by timestamp for Lotek receivers.
#'
#' @param serno character vector of serial numbers
#'
#' @param ts numeric vector with non-NA entries wherever \code{serno}
#'     is a Lotek receiver. Can be \code{NULL}, the default, if all
#'     \code{serno} are SensorGnomes.
#'
#' @param bootnum integer vector with non-NA entries wherever
#'     \code{serno} is a SensorGnome.  Can be \code{NULL}, the
#'     default, if all \code{serno} are Lotek receivers.
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

getYearProjSite = function(serno, ts=NA, bootnum=NA) {
    serts = data_frame(serno   = serno,
                       ts      = ts,
                       bootnum = bootnum,
                       year    = as.integer(NA),
                       proj    = as.character(NA),
                       site    = as.character(NA)
                       )

    isLotek = grepl("^Lotek-", serno, perl=TRUE)
    lotek = subset(serts, isLotek)
    sg = subset(serts, ! isLotek)

    ## use a temporary database to do this as a join query
    con = dbConnect(RSQLite::SQLite(), ":memory:")
    sql = function(...) dbGetQuery(con, sprintf(...))

    sql("attach database '%s' as d", MOTUS_RECV_MAP_DB)

    ## look up Lotek sites by serial number and timestamp

    if (nrow(lotek) > 0) {
        dbWriteTable(con, "lotek", lotek %>% as.data.frame, row.names=FALSE)

        ## get latest row (largest tsHi) that is still no later than ts for each receiver
        sql("create table reslotek as select t1.serno as serno, t1.ts as year, t2.Project as proj, t2.Site as site from lotek as t1 left outer join d.map as t2 on t1.serno = t2.Serno and t2.tsLo = (select max(t3.tsLo) from d.map as t3 where t3.Serno=t2.Serno and t3.tsLo <= t1.ts)")

        lotek = sql("select * from reslotek")

        lotek$year = as.integer(year(structure(lotek$year, class=class(Sys.time()))))
    }

    ## look up sensorgnome sites by serial number and boot number

    if (nrow(sg) > 0) {
        dbWriteTable(con, "sg", sg %>% as.data.frame, row.names=FALSE)

        ## get latest row (largest boot) that is still no later than ts for each receiver
        sql("create table ressg as select t1.serno as serno, t2.Year as year, t2.Project as proj, t2.Site as site from sg as t1 left outer join d.bootnumMap as t2 on t1.serno = t2.Serno and t2.BootnumLo = (select max(t3.BootnumLo) from d.bootnumMap as t3 where t3.Serno=t2.Serno and t3.BootnumLo <= t1.bootnum)")

        sg = sql("select * from ressg")
    }
    dbDisconnect(con)
    return(rbind(lotek, sg))
}
