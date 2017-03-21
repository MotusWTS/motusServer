#' plot data from a receiver
#'
#' @details Generate unified status / data plots and datasets for a receiver.
#' If the top-level job has a motusProjectID field, then this function plots
#' only the data for receiver deployments belonging to that project.
#'
#' @param j the job, with these fields:
#' \itemize{
#' \item serno - the receiver serial number
#' \item monoBN - the range of receiver bootnums; NULL for Lotek receivers.
#' \item ts - the approximate range of timestamps; NULL for SGs.
#' }
#'
#' @return TRUE
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handlePlotData = function(j) {
    serno = j$serno
    ts = j$ts
    monoBN = j$monoBN
    isLotek = grepl("^Lotek", serno, perl=TRUE)
    tj = topJob(j)
    motusProjectID = tj$motusProjectID
    motusUserID = tj$motusUserID

    lockSymbol(serno)

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockSymbol(serno, lock=FALSE))

    info = getYearProjSite(serno, ts=ts, bn=monoBN, motusProjectID)

    if (is.null(info)) {
        jobLog(j, paste0("Warning: no deployments found for receiver ", serno, " and ts ",
                         paste0(format(structure(ts, class=class(Sys.time()))), collapse=","),
                         " and bn ", paste0(monoBN, collapse=",")))
        return(TRUE)
    }

    ## get a tagview for the detections in this receiver (a tagview joins batches/runs/hits with appropriate metadata)
    src = getRecvSrc(serno)
    mot = getMotusMetaDB()

    ## for each deployment, do a plot

    ## plot only the first detection of each tag by each antennna in each condensation period
    ## Condensation periods are in seconds.

    condense = 3600
    condenseLabel = "hourly"

    if (length(motusProjectID) > 0) {
        info = subset(info, projID == motusProjectID)
    }

    ## get rid of empty deployments; i.e. those for which we don't actually have data.
    info = subset(info, !(is.na(tsStart) & is.na(bnStart)))

    outDir = file.path(MOTUS_PATH$PLOTS, serno)
    dir.create(outDir, mode="0770")

    for (i in 1:nrow(info)) {
        year = info$year[i]
        proj = info$proj[i]
        site = info$site[i]

        title = sprintf("%d %s %s Tags (%s)", year, proj, site, condenseLabel)
        datafilename = file.path(outDir, sprintf("%s-%d_%s_%s_%s_tags.rds", serno, year, proj, site, condenseLabel))
        plotfilename = sub("\\.rds$", "\\.png", datafilename, perl=TRUE)

        ## generate the plot object and condensed dataset
        rv = makeReceiverPlot(src, mot, title, condense, ts = unlist(info[i, c("tsStart", "tsEnd")]), unlist(info[i, c("bnStart", "bnEnd")]))

        saveRDS(rv$data, datafilename)
        png(plotfilename, width=rv$width, height=rv$height, type="cairo-png")
        print(rv$plot)
        dev.off()

        ## make a pdf too, assuming a 90 dpi display
        pdfname = sub("\\.png$", ".pdf", plotfilename, perl=TRUE)
        pdf(pdfname, width=rv$width / 90, height=rv$height / 90)
        print(rv$plot)
        dev.off()

        targDir = file.path(MOTUS_PATH$WWW, info$projID[i])
        file.symlink(plotfilename, targDir)
        file.symlink(pdfname, targDir)
        file.symlink(datafilename, targDir)
        jobLog(j, paste0("Exported hourly dataset (and plot) to:  ", basename(datafilename), "(.png/.pdf)"))
    }
    closeRecvSrc(src)

    ## TODO: make links to files in users's downloads folder
    ## jobLog(j, paste0('Uploaded hourly data and plot to wiki page here: <a href="', wikiLink, '">', wikiLink, '</a>'), summary=TRUE)
    return (TRUE)
}
