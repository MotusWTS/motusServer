#' Get project and site names, given a receiver serial number and a time range
#' or bootnum range.
#'
#' This is meant to provide project and site labels for plots and
#' summary files.  Either a time range (tsLo, tsHi) or a boot number
#' range (bnLo, bnHi) must be provided, but not both.
#'
#' If a time range is provided, all deployments that overlap the
#' specified time range are returned, and the range of timestamps for
#' these deployments is returned in the tsStart, tsEnd fields.
#'
#' If a boot session range is provided, all deployments that include
#' the specified boot session range are returned, and the range of
#' boot sessions from these is returned in the bnStart, bnEnd fields.
#' It is assumed the caller has obtained a lock on that receiver's DB,
#' via \code{lockSymbol(serno)}.
#'
#' In either case, if the receiver is a SensorGnome, the return value includes
#' valid bnStart and bnEnd - the range of boot sessions corresponding to
#' the corresponding receiver deployment.
#'
#' @param serno character vector of serial numbers
#'
#' @param ts numeric vector of length 2; start and end time
#'
#' @param bn integer vector of length 2; start and end boot session numbers
#'
#' @param motusProjectID integer scalar; motus project ID to use in case no deployments found
#' for this receiver.
#'
#' @return a data.frame with these columns:
#' \itemize{
#' \item serno receiver serial number
#' \item year integer year deployment began
#' \item proj name of project
#' \item site name of receiver deployment
#' \item projID id of project
#' \item tsStart timestamp at which this deployment begins
#' \item tsEnd timestamp at which this deployment ends
#' \item bnStart boot number at which this deployment begins
#' \item bnEnd boot number at which this deployment ends
#' }
#' Returns NULL if neither bn nor ts is specified.
#'
#' If there were no matching deployment records, and no motus project
#' is given, then the catch-all project 0 is used.
#'
#' @seealso \link{\code{lockSymbol}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getYearProjSite = function(serno, ts=NULL, bn=NULL, motusProjectID=NULL) {

    ## check for SG
    isSG = grepl("^SG-", serno)
    if (isSG) {
        rdb = safeSQL(getRecvSrc(serno))
    }
    ## if bn range specified, convert to a timestamp range

    if (!is.null(bn)) {
        if (!isSG)
            stop("Trying to look up Lotek receiver metadata by boot number; use ts instead")
        tr = rdb("select min(tsBegin) as tsLo, max(tsEnd) as tsHi from batches where monoBN between :lo and :hi and tsBegin >= :valid",
                 lo = bn[1], hi = bn[2], valid=MOTUS_SG_EPOCH)
        if (nrow(tr) == 0)
            return (NULL)
        ts = unlist(tr)
    } else {
        if (is.null(ts))
            return(NULL)
        bn = c(NA, NA)
    }

    info = data.frame(serno   = serno,
                      tsLo    = ts[1],
                      tsHi    = ts[2],
                      bnLo    = bn[1],
                      bnHi    = bn[2],
                      year    = as.integer(NA),
                      proj    = as.character(NA),
                      site    = as.character(NA),
                      tsStart = NA,
                      tsEnd   = NA,
                      bnStart = NA,
                      bnEnd   = NA,
                      stringsAsFactors=FALSE
                      )

    ## use a temporary database to do this as a join query
    meta = safeSQL(getMotusMetaDB())

    dbWriteTable(meta$con, "temp.info", info %>% as.data.frame, row.names=FALSE)

    ## look up deployments by serial number and timestamp

    ## get latest row (largest tsHi) that is still no later than ts for the receiver

    rv = meta(sprintf("select t1.serno as serno, 0 as year, t3.id as projID, t3.label as proj, t2.name as site, t2.tsStart as tsStart, t2.tsEnd as tsEnd, null as bnStart, null as bnEnd from temp.info as t1 join recvDeps as t2 on t1.serno = t2.serno and t2.tsStart <= t1.tsHi and (t2.tsEnd is null or t2.tsEnd >= t1.tsLo) left join projs as t3 on t2.projectID=t3.id", MOTUS_SG_EPOCH, MOTUS_SG_EPOCH))

    ## for some reason, the above leads to a character column if there's an NA anywhere in it
    rv$tsStart = as.numeric(rv$tsStart)
    rv$year = as.integer(year(structure(rv$tsStart, class=class(Sys.time()))))

    if (isSG) {
        ## now fill in which range of boot sessions the deployment(s) cover (or overlap)
        ## a boot session overlaps a deployment if it begins before the deployment ends and ends
        ## after the deployment begins.
        for (i in seq(along=rv$serno)) {
            rv[i, c("bnStart", "bnEnd")] = unlist(rdb("select min(monoBN) as bnLo, max(monoBN) as bnHi from batches where (:tsHi is null or tsBegin <= :tsHi) and tsEnd >= :tsLo",
                      tsLo = rv$tsStart[i], tsHi = rv$tsEnd[i]))
        }
        rdb(.CLOSE=TRUE)
    }

    ## again, why are some of these of class "character"
    rv$bnStart = as.integer(rv$bnStart)
    rv$bnEnd = as.integer(rv$bnEnd)

    meta(.CLOSE=TRUE)
    if (nrow(rv) > 0)
        return(rv)

    if (length(motusProjectID) == 0)
        motusProjectID = 0L

    ## generate a provisional deployment for the given project
    ## get project name
    meta = safeSQL(getMotusMetaDB())
    if (motusProjectID > 0)
        proj = meta(sprintf("select label from projs where id=%d", motusProjectID))[[1]]
    else
        proj = "no_project"
    meta(.CLOSE=TRUE)

    if (isSG) {
        recv = safeSQL(getRecvSrc(serno))
        info = recv(sprintf("select min(tsBegin), max(tsEnd) from batches where monoBN between %d and %d and tsBegin > %18f and tsEnd > %18f",bn[1], bn[2], MOTUS_SG_EPOCH, MOTUS_SG_EPOCH))
        recv(.CLOSE=TRUE)
        return (data.frame(
            serno = serno,
            year = year(structure(info[1,1], class=class(Sys.time()))),
            proj = proj,
            site = "unregistered_deployment",
            projID = motusProjectID,
            tsStart = info[1, 1],
            tsEnd = info[1, 2],
            bnStart = bn[1],
            bnEnd = bn[2],
            stringsAsFactors = FALSE))

    } else {
        return (data.frame(
            serno = serno,
            year = year(structure(ts[1], class=class(Sys.time()))),
            proj = proj,
            site = "(unregistered deployment)",
            projID = motusProjectID,
            tsStart = ts[1],
            tsEnd = ts[2],
            bnStart = NA,
            bnEnd = NA,
            stringsAsFactors = FALSE))
    }
}
