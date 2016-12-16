#' export data the 'old' (pre-motus) way.
#'
#' @details We generate Year/Proj/Site plots for the receiver, showing
#'     hourly tag detections and antenna status, then upload these to
#'     the user's wiki page at sensorgnome.org
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
    tsStart = info$tsStart
    monoBNStart = info$bootnumStart

    if (is.na(site)) {
        msg = paste0("Warning: unable to determine Year / Proj / Site for ", serno)
        if (isLotek) {
            msg = paste0(msg, " in ts range: ", paste(ts, collapse=", "))
        } else {
            msg = paste0(msg, " in monoBN (boot sessions): ", paste(monoBN, collapse=", "))
        }
        jobLog(j, msg)
    } else {
        ## extend ts or monoBN to start of deployment
        ts[1] = min(ts[1], tsStart)
        monoBN[1] = min(monoBN[1], monoBNStart)
    }

    ## get a tagview for the detections in this receiver (a tagview joins batches/runs/hits with appropriate metadata)
    src = getRecvSrc(serno)
    mot = getMotusMetaDB()

    ## plot only the first detection of each tag by each antennna in each condensation period
    ## Condensation periods are in seconds.

    condense = 3600
    condenseLabel = "hourly"

    if (! is.na(site)) {
        title = sprintf("%d %s %s Tags (%s)", year, proj, site, condenseLabel)
        datafilename = sprintf("/SG/contrib/%d/%s/%s/%d_%s_%s_%s_tags.rds", year, proj, site, year, proj, site, condenseLabel)
    } else {
        title = sprintf("Tags for receiver %s (%s) - Project and Site Unknown", serno, condenseLabel)
        datafilename = sprintf("/sgm/plots/%s_%s_tags.rds", serno, condenseLabel)
    }
    plotfilename = sub("\\.rds$", "\\.png", datafilename, perl=TRUE)

    ## generate the plot object and condensed dataset
    rv = makeReceiverPlot(src, mot, title, condense, ts, range(monoBN))

    closeRecvSrc(src)

    saveRDS(rv$data, datafilename)
    png(plotfilename, width=rv$width, height=rv$height, type="cairo-png")
    print(rv$plot)
    dev.off()

    ## make a pdf too, assuming a 90 dpi display
    pdfname = sub("\\.png$", ".pdf", plotfilename, perl=TRUE)
    pdf(pdfname, width=rv$width / 90, height=rv$height / 90)
    print(rv$plot)
    dev.off()

    jobLog(j, paste0("Exported hourly dataset (and plot) to:  ", basename(datafilename), "(.png/.pdf)"))

    if (! is.na(site)) {
        system(sprintf("cd /SG/contrib/%d/%s/%s; /SG/code/attach_site_files_to_wiki.R", year, proj, site))

        ## get the wiki user for this site
        con = dbConnect(SQLite(), "/SG/motus_sg.sqlite")
        user = dbGetQuery(con, paste0("select SGwikiUser from projectMap where year=", year, " and ProjCode='", proj, "'"))[[1]]
        dbDisconnect(con)

        wikiLink = sprintf('https://sensorgnome.org/User:%s/%s', user, site)
    } else {
        user = topJob(j)$user
        for (f in c(datafilename, plotfilename, pdfname)) {
            safeSys(sprintf("/SG/code/wiki_attach.R sensorgnome \"^%s$\" \"%s\"", user, f), quote=FALSE, minErrorCode=3)
        }
        wikiLink = sprintf('https://sensorgnome.org/User:%s', user)
    }
    jobLog(j, paste0('Uploaded data and plot to wiki page here: <a href="', wikiLink, '">', wikiLink, '</a>'))
    return (TRUE)
}
