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

    if(TRUE) {
        motusReceiverID = MetaDB(paste0("select id from recvDeps where serno = '", serno, "' and projectID = ", motusProjectID, " limit 1"))
        motusReceiverID = motusReceiverID[!is.na(motusReceiverID)]
        if(length(motusReceiverID) == 0) {
            jobLog(j, paste0("\n", serno, ": no deployments are known in this project for this receiver. Please enter a deployment for this receiver on the website. The receivers of project ", motusProjectID, " can be viewed at https://motus.org/data/projectReceivers?id=", motusProjectID), summary=TRUE)
        } else {
            motusDeployIDs = MetaDB(paste0("select deployID from recvDeps where serno = '", serno, "' and projectID = ", motusProjectID, " order by deployID desc"))
            motusDeployIDs = motusDeployIDs[!is.na(motusDeployIDs)]
            if(length(motusDeployIDs) == 0) {
                jobLog(j, paste0("\n", serno, ": no deployments are known in this project for this receiver. Please enter a deployment for this receiver at https://motus.org/data/receivers/edit?id=", motusReceiverID, "&projectID=", motusProjectID, ". A plot of activity for this receiver can be viewed at https://motus.org/data/receiver/timeline?id=", motusReceiverID), summary=TRUE)
            } else {
                jobLog(j, paste0("\n", serno, "\n  A plot of activity for this receiver can be viewed at https://motus.org/data/receiver/timeline?id=", motusReceiverID), summary=TRUE)
                for (deployID in motusDeployIDs) {
                    jobLog(j, paste0("\n  A table of the most recently detected tags for deployment #", deployID, " can be viewed at https://motus.org/data/receiverDeploymentDetections?o=0d&id=", deployID), summary=TRUE)
                }
            }
        }
        return(TRUE)
    }

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

    ## for each deployment, do a plot

    ## plot only the first detection of each tag by each antennna in each condensation period
    ## Condensation periods are in seconds.

    condense = 3600
    condenseLabel = "hourly"

    if (isTRUE(motusProjectID > 0)) {
        info = subset(info, projID == motusProjectID)
    }

    ## get rid of empty deployments; i.e. those for which we don't actually have data.
    info = subset(info, !(is.na(tsStart) & is.na(bnStart)))

    ## group by year, proj, site to keep all "deployments" together (multiple deployments might differ
    ## only in antenna placement; we want these on the same plots)

    info = info %>% group_by(year, proj, site) %>% summarize(serno=first(serno), projID=first(projID), tsStart=min(tsStart, na.rm=TRUE), tsEnd=max(tsEnd, na.rm=TRUE), bnStart=min(bnStart, na.rm=TRUE), bnEnd = max(bnEnd, na.rm=TRUE))

    ## deal with -Inf for tsEnd arising from max(c()); set to a very long time in the future.
    info$tsEnd[! is.finite(info$tsEnd)] = 1e20

    isTesting = isTRUE(topJob(j)$isTesting)
    outDir = productsDir(j$serno, isTesting)

    for (i in seq_len(nrow(info))) {
        year = info$year[i]
        proj = info$proj[i]
        site = info$site[i]

        title = sprintf("%.0f %s %s Tags (%s)", year, proj, site, condenseLabel)
        datafilename = file.path(outDir, sprintf("%s-%.0f_%s_%s_%s_tags.rds", serno, year, proj, gsub("/", ";", site, fixed=TRUE), condenseLabel))
        plotfilename = sub("\\.rds$", "\\.png", datafilename, perl=TRUE)

        ## generate the plot object and condensed dataset
        rv = NULL
        prods = NULL
        tryCatch({
            rv = makeReceiverPlot(src, MOTUS_METADB_CACHE, title, condense, ts = unlist(info[i, c("tsStart", "tsEnd")]), unlist(info[i, c("bnStart", "bnEnd")]))
            if (!is.null(rv)) {
                saveRDS(rv$data, datafilename)
                prods = datafilename
                ## make a pdf too, assuming a 90 dpi display
                pdfname = sub("\\.png$", ".pdf", plotfilename, perl=TRUE)
                pdf(pdfname, width=rv$width / 90, height=rv$height / 90)
                print(rv$plot)
                dev.off()
                prods = c(prods, pdfname)

                png(plotfilename, width=rv$width, height=rv$height, type="cairo-png")
                print(rv$plot)
                dev.off()
                prods = c(prods, plotfilename)
            }
        }, error = function(e) {
            jobLog(j, paste0("Error `", as.character(e), "` while trying to make plot for ", serno, " ", year, "_", proj, "_", site))
        })
        if (length(prods) > 0) {
            registerProducts(j, path=prods, projectID=info$projID[i], isTesting=isTesting)
        }
    }
    closeRecvSrc(src)
    return (TRUE)
}
