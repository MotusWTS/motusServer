#' make a plot of tag detections and status of antennas
#'
#' The plot is an object of class \code{trellis} which can then
#' be sent to an open plotting device using \code{print()}.
#'
#' @param recv path or dplyr::src_sqlite to the receiver database
#'
#' @param meta path or dplyr::src_sqlite to the file with metadata; if
#'     NULL (the default), assume metadata tables are in the database
#'     given by \code{recv}
#'
#' @param title additional title to identify plot, beyond receiver
#'     serial number
#'
#' @param condense double scalar; if not NULL, specifies the
#'     condensation period: only the first detection of a given tag on
#'     a given antenna per condensation period is plotted.  Default:
#'     3600, meaning at most one detection of each tag on each antenna
#'     is shown per hour, and it will be the first for that hour.
#'
#' @param ts double vector of length 2; range of timestamps to plot;
#'     Default: NULL, meaning no restriction on timestamps.
#'
#' @param monoBN integer vector of length 2; range of boot sessions to
#'     plot; Default: NULL, meaning no restriction on boot sessions.
#'
#' @details If both \code{ts} and \code{monoBN} are NULL, then all
#'     detections in database \code{recv} are plotted.
#'
#' @return a list with these items:
#' \itemize{
#'
#' \item width: recommended plot width, in pixels
#'
#' \item height: recommended plot height, in pixels
#'
#' \item plot: object of class \code{trellis}; to generate a plot from
#' this:
#'
#' \itemize{
#'
#' \item open a graphics device, using the recommended width and
#' height
#'
#' \item print the plot
#'
#' \item close the device
#'
#' }
#'
#' \item data: dataframe of the data plotted, with these columns
#'
#' \itemize{
#'
#' \item ant: antenna number
#'
#' \item fullID full tag ID, or " Antenna N "; the latter 'detections'
#' just indicate the antenna was functioning in the hour centred on
#' the timestamp
#'
#' \item bin: the bin number for condensation
#'
#' \item ts: the timestamp at the start of the condensation bin
#'
#' \item n: the number of detections (will be at least 1)
#'
#' \item freq: the mean offset frequency of detections
#'
#' \item sig: the \emph{maximum} signal strength
#'
#' }
#'
#' Note: \code{n}, \code{freq}, and \code{sig} are for the given tag and antenna
#' during the condensation period.
#'
#' }
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

makeReceiverPlot = function(recv, meta=NULL, title="", condense=3600, ts = NULL, monoBN = NULL) {
    if (is.character(recv))
        recv = src_sqlite(recv)
    if (is.null(meta)) {
        meta = recv
    } else if (is.character(meta)) {
        meta = src_sqlite(meta)
    }

    ## grab receiver serial number from "meta" map in recv database
    rinfo = getMap(recv)
    serno = rinfo$recvSerno
    isLotek = rinfo$recvType == "Lotek"

    ## get a tagview for the detections in this receiver (a tagview joins batches/runs/hits with appropriate metadata)
    tags = tagview(recv, meta)

    ## do usual filtering on freqsd, run length
    tags = tags %>% filter_(~(is.na(freqsd) | freqsd < 0.1) & len >= 3)

    ## filter by monoBN or ts

    if (isLotek) {
        if (! is.null(ts)) {
            tags = tags %>% filter_ (~ts >= ts[1] & ts <= ts[2])
        }
    } else {
        if (! is.null(monoBN)) {
            monoBNlo = min(monoBN)
            monoBNhi = max(monoBN)
            tags = tags %>% filter_ (~monoBN >= monoBNlo & monoBN <= monoBNhi)
        }
    }

    ## create bin column for condensation, if requested and sane
    if (! is.null(condense) & isTRUE(condense > 0)) {
        tags = tags %>% mutate(bin = floor(ts/condense))
    } else {
        ## won't / can't condense, so bin is just timestamp itself
        tags = tags %>% mutate(bin = ts)
    }

    ## group by antenna, tag, and time bin

    tags = tags %>% group_by(ant, fullID, bin)

    ## summarize detections in group into a data.frame

    ## Note: when bin is ts, each group has size one, so min(x),
    ## avg(x), and max(x) are all just x

    tags = tags %>% summarize(ts=min(ts), n=length(ts),
        freq=avg(freq), sig=max(sig)) %>% collect %>% as.data.frame

    ## drop ".0" suffix from Ids, as it is wrong (FIXME: this should be done in getMotusMetaDB())

    fixup = which(grepl(".0@", tags$fullID, fixed=TRUE))
    tags$fullID[fixup] = sub(".0@", "@", tags$fullID[fixup], fixed=TRUE)

    tags$fullID = as.factor(tags$fullID)
    ## get pulse counts to show as status, and append to the dataset
    ## Fixme: if anyone cares, they can recode this in dplyr form

    if (! isLotek) {
        pulses = dbGetQuery(recv$con, "select ant, ' Antenna ' || ant as fullID, hourBin as bin, hourBin * 3600 + 1800 as ts, 1 as n, 0 as freq, 0 as sig from pulseCounts")
        pulses$fullID = as.factor(pulses$fullID)
        tags = rbind(tags, pulses)
    }

    class(tags$ts) = c("POSIXt", "POSIXct")

    dayseq = seq(from=round(min(tags$ts), "days"), to=round(max(tags$ts),"days"), by=24*3600)

    ylab = "Full Tag ID"
    numTags = length(unique(tags$fullID))  ## compute separately for each plot
    width = 1024
    height = 300 + 20 * numTags
    dateLabel = sprintf("Date (%s, GMT)", paste(format(range(tags$ts), "%Y %b %d %H:%M"), collapse=" to "))
    plot = xyplot(
        fullID~ts,
        groups = ant, data = tags,
        panel = function(x, y, groups, ...) {
            panel.abline(h=unique(y), lty=2, col="gray")
            panel.abline(v=dayseq, lty=3, col="gray")
            ant = grepl("^ Antenna ", y, perl=TRUE)
            panel.xyplot(x[ant], y[ant], groups=groups[ant], pch = 15, ...)
            panel.xyplot(x[! ant], y[! ant], groups=groups[! ant], ...)
        },
        main = list(c(title,sprintf("Receiver: %s", serno)), cex=1.5),
        ylab = list(ylab, cex=1.5),
        xlab = list(dateLabel, cex=1.5),
        cex = 1.5,
        scales=list(cex = 1.5),
        )

    return (list(
        width = width,
        height = height,
        plot = plot,
        data = tags
        ))
}
