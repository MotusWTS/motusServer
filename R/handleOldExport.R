#' export data the 'old' (pre-motus) way.
#'
#' @details We generate Year/Proj/Site plots for the receiver, showing tag
#' detections and receiver status, then upload these to the user's wiki
#' page at sensorgnome.org
#'
#' @param j the job, with these fields:
#' \itemize{
#' \item serno - the receiver serial number
#' \item monoBN - the range of receiver bootnums; NULL for Lotek receivers.
#' \item ts - the approximate range of timestamps; NULL for SGs.
#' }
#'
#' @return TRUE if the export succeeded
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleOldExport = function(j) {
    serno = j$serno
    ts = j$ts
    monoBN = j$monoBN
    isLotek = grepl("^Lotek", serno, perl=TRUE)

    while(! lockReceiver(serno)) {
        ## FIXME: we should probably return NA immediately, and have processServer re-queue the job at the end of the queue
        Sys.sleep(10)
    }

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockReceiver(serno, FALSE))

    info = tail(getYearProjSite(serno, ts=ts, bootnum=monoBN), 1)
    year = info$year
    proj = info$proj
    site = info$site
    if (is.na(site))
        return(FALSE)

    ## get a tagview for the detections in this receiver (a tagview joins batches/runs/hits with appropriate metadata)
    src = sgRecvSrc(serno)
    mot = getMotusMetaDB()
    tags = tagview(src, mot)

    ## group detections by antenna, tag, and hour
    tags = tags %>% filter_(~(is.na(freqsd) | freqsd < 0.1) & len >= 3) %>% mutate(hourBin = round(ts/3600-0.5, 0)) %>% group_by(ant, fullID, hourBin)

    ## filter by monoBN or ts
    if (isLotek) {
        ## look at past 8 months for receiver
        tlo = ts[2] - 24 * 3600 * 240
        tags = tags %>% filter_ (~ts >= tlo & ts <= ts[2])
    } else {
        monoBNlo = min(monoBN)
        monoBNhi = max(monoBN)
        tags = tags %>% filter_ (~monoBN >= monoBNlo & monoBN <= monoBNhi)
    }

    ## summarize detections in group
    tags = tags %>% summarize(ts=min(ts), n=length(ts), freq=avg(freq), sig=max(sig)) %>%
        collect %>% as.data.frame

    ## ## add recv column
    ## if (tags %>% head(1) %>% collect %>% nrow > 0) {
    ##     tags$recv = oldrec$recv[i]
    ##     tags$new = TRUE
    ## }

    ## drop ".0" suffix from Ids, as it is wrong (FIXME: this should be done in getMotusMetaDB())

    fixup = which(grepl(".0@", tags$fullID, fixed=TRUE))
    tags$fullID[fixup] = sub(".0@", "@", tags$fullID[fixup], fixed=TRUE)

    ## ## re-arrange components of fullID to: ID:BI#PROJ@FREQ
    ## tags$physID = stri_replace_all_regex(tags$fullID, "(.*)#(.*):(.*)@(.*)", "$2:$3@$4")
    ##
    ## ## re-arrange components of fullID to: ID:BI#PROJ@FREQ
    ## tags$fullID = stri_replace_all_regex(tags$fullID, "(.*)#(.*):(.*)@(.*)", "$2:$3#$1@$4")

    class(tags$ts) = c("POSIXt", "POSIXct")

    dayseq = seq(from=round(min(tags$ts), "days"), to=round(max(tags$ts),"days"), by=24*3600)

    datafilename = sprintf("/SG/contrib/%d/%s/%s/%d_%s_%s_hourly_tags.rds", year, proj, site, year, proj, site)
    saveRDS(tags, datafilename)

    ylab = "Full Tag ID"
    numTags = length(unique(tags$fullID))  ## compute separately for each plot
    plotfilename = sprintf("/SG/contrib/%d/%s/%s/plots/%d_%s_%s_hourly_tags.png", year, proj, site, year, proj, site)
    png(plotfilename, width=1024, height=300 + 20 * numTags, type="cairo-png")
    rv = c(rv, plotfilename)
    dateLabel = sprintf("Date (%s, GMT)", dateStem(tags$ts[c(1, nrow(tags))]))

    print(xyplot(as.factor(fullID)~ts,
                 groups = new, data = tags,
                 panel = function(x, y, groups) {
                     panel.abline(h=unique(y), lty=2, col="gray")
                     panel.abline(v=dayseq, lty=3, col="gray")
                     panel.xyplot(x, y, pch = ifelse(groups, newSym, oldSym), col = ifelse(groups, 2, 1), cex=2)
                 },
                 auto.key = list(
                     title="Data Source",
                     col=c(2, 1), points=FALSE, text=c("new: ^", "old: v")
                 ),
                 main = sprintf("%d %s %s Hourly Tags", year, proj, site),
                 sub = sprintf("Receiver: %s", serno),
                 ylab = ylab,
                 xlab = dateLabel
                 )
          )
    dev.off()
    system(sprintf("cd /SG/contrib/%d/%s/%s; /SG/code/attach_site_files_to_wiki.R", year, proj, site))

    return (TRUE)
}
