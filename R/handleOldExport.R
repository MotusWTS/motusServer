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
    if (is.na(site))
        return(FALSE)

    ## get a tagview for the detections in this receiver (a tagview joins batches/runs/hits with appropriate metadata)
    src = sgRecvSrc(serno)
    mot = getMotusMetaDB()
    tags = tagview(src, mot)

    ## plot only the first detection of each tag by each antennna in each condensation period
    ## Condensation periods are in seconds.

    condense = 3600
    condenseLabel = "hourly"

    title = sprintf("%d %s %s Tags (%s)", year, proj, site, condenseLabel)
    datafilename = sprintf("/SG/contrib/%d/%s/%s/%d_%s_%s_%s_tags.rds", year, proj, site, year, proj, site, condenseLabel)
    plotfilename = sub("\\.rds$", "\\.png", datafilename, perl=TRUE)

    ## generate the plot object and condensed dataset
    rv = makeReceiverPlot(src, mot, title, condense, ts, range(monoBN))

    saveRDS(rv$data, datafilename)
    png(plotfilename, width=rv$width, height=rv$height, type="cairo-png")
    print(rv$plot)
    dev.off()

    ## make a pdf too, assuming a 90 dpi display
    pdf(sub("\\.png$", ".pdf", plotfilename, perl=TRUE), width=rv$width / 90, height=rv$height / 90)
    print(rv$plot)
    dev.off()


    jobLog(j, paste0("Exported hourly dataset (and plot) to:  ", basename(datafilename), "(.png/.pdf)"))

    system(sprintf("cd /SG/contrib/%d/%s/%s; /SG/code/attach_site_files_to_wiki.R", year, proj, site))

    jobLog(j, paste0("Uploaded hourly dataset and plot to sensorgnome.org wiki page"))
    return (TRUE)
}
