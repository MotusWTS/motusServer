#' make a plot of tag detections and status of antennas
#'
#' The plot is an object of class \code{trellis} which can then
#' be sent to an open plotting device using \code{print()}.
#' Note: only detections with valid timestamps, i.e. after
#' 1 Jan 2010, are shown.
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
#' @param antCol colours to use for each antenna, beginning with antenna number 0.
#' Antenna numbers run from 0 to 10, so at most the first 11 elements are used.
#'
#' Default:
#' \code{
#'  c(
#'   "#000000", ## black
#'   "#0000ff", ## blue
#'   "#20bd00", ## green
#'   "#a617b8", ## purple
#'   "#fb7402", ## orange
#'   "#11d0e1", ## cyan
#'   "#18770b", ## dark green
#'   "#e7c00a", ## gold
#'   "#ff0000", ## red
#'   "#5eff00", ## yellow green
#'   "#a5a5a5"  ## gray
#'   )
#' }
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
#' \item fullID full tag ID, or " Antenna N Status"; the latter
#' 'detections' just indicate the antenna was functioning in the hour
#' centred on the timestamp.  Also, a fullID of
#' " Reboot Odometer" indicate the approximate timestamps at
#' which the receiver rebooted, and the \code{ant} field for these
#' records is the last digit of the boot session count.
#'
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

makeReceiverPlot = function(recv, meta=NULL, title="", condense=3600, ts = NULL, monoBN = NULL, antCol=c("#000000", "#0000ff", "#20bd00", "#a617b8", "#fb7402", "#11d0e1", "#18770b", "#e7c00a", "#ff0000", "#5eff00", "#a5a5a5")
) {
    owner = list(recv=FALSE, meta=FALSE)

    if (is.character(recv)) {
        recv = src_sqlite(recv)
        owner$recv = TRUE
    }
    if (is.null(meta)) {
        meta = recv
    } else if (is.character(meta)) {
        meta = src_sqlite(meta)
        owner$meta = TRUE
    }

    ## on exit, close DB connections we opened; dplyr has finalizers for these, but we
    ## want to avoid building up too much cruft before the next gc()

    on.exit(for (n in names(owner)) if (owner[[n]]) dbDisconnect(get(n)$con))

    ## grab receiver serial number from "meta" map in recv database
    rinfo = getMap(recv)

    if (! isTRUE(rinfo$dbType == "receiver"))
        stop("This is not a receiver database.  Use a different function for plotting tagProject or site databases.")

    serno = rinfo$recvSerno
    isLotek = rinfo$recvType == "Lotek"

    ## get a tagview for the detections in this receiver (a tagview joins batches/runs/hits with appropriate metadata)
    tags = tagview(recv, meta)

    ## do usual filtering on freqsd, run length
    tags = tags %>% filter_(~(is.na(freqSD) | freqSD < 0.1) & len >= 3)

    ## filter by monoBN or ts

    if (isLotek) {
        if (! is.null(ts)) {
            ts = unname(ts)
            if (is.na(ts[2])) {
                ts[2] = as.numeric(Sys.time())
            }
            myts = ts
            tags = tags %>% filter_ (~ts >= myts[1] & ts <= myts[2])
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

    tags = tags %>% group_by(ant, tagID, bin)

    ## summarize detections in group into a data.frame

    ## Note: when bin is ts, each group has size one, so min(x),
    ## avg(x), and max(x) are all just x

    tags = tags %>% summarize(ts=min(ts), n=length(ts),
        freq=avg(freq), sig=max(sig), fullID=fullID, mfgID=mfgID, proj=label) %>% collect %>% as.data.frame

    ## drop ".0" suffix from Ids, as it is wrong (FIXME: this should be done in getMotusMetaDB())

    fixup = which(grepl(".0@", tags$fullID, fixed=TRUE))
    if (length(fixup))
        tags$fullID[fixup] = sub(".0@", "@", tags$fullID[fixup], fixed=TRUE)

    ## append motus ID
    tags$fullID = sprintf("%s M.%d", tags$fullID, tags$tagID)

    ## make into a factor, sorting levels by project label, and then increasing mfgID
    tags$fullID = factor(tags$fullID, levels = unique(tags$fullID[order(tags$proj, as.numeric(tags$mfgID))]))

    ## for ambiguous tags, add items to the y-axis label
    mID = unique(tags$tagID)

    xlabExtra = ""
    heightExtra = 0
    if (isTRUE(any(mID < 0))) {
        aID = mID[mID < 0]
        ambig = dbGetQuery(recv$con, paste0("
select ambigID, motusTagID1, motusTagID2, motusTagID3, motusTagID4, motusTagID5, motusTagID6
from tagAmbig where ambigID in (", paste0(aID, collapse=","), ")"))
        xlabExtra = paste0("\nAmbiguous Tags: ",
                           paste( sapply(1:nrow(ambig),
                                         function(i) {
                                             a = ambig[i, -1]
                                             a = a[!is.na(a)]
                                             paste0("M.", ambig[i, 1], " = ", paste0("M.", a, collapse=" or "))
                                         }
                                         ), collapse="; "
                                 ))
        ## adjust plot height for extra lines
        heightExtra = 20
    }

    ## remove fields we no longer need, so we don't have to pad the
    ## pulse and boot pseudo-tag records

    tags$mfgID = tags$proj = tags$tagID = NULL

    ## if all frequencies are the same, remove from fullID and append to axis label

    freqs = unique(unlist(regexPieces("@(?<freq>[0-9.]*)", levels(tags$fullID))))
    ylabExtra = ""
    if (length(freqs) == 1) {
        levels(tags$fullID) = sub("@[0-9.]*", "", levels(tags$fullID), perl=TRUE)
        ylabExtra = paste0(ylabExtra, "\nall tags @ ", freqs, " MHz")
    }

    ## get GPS fixes

    if (isLotek) {
        ## get GPS fixes from the period in question; grab any from batches that overlap
        ## the specified time interval; further filtering happens below

        gps = dbGetQuery(recv$con, sprintf("
select 1 as ant,
' GPS Fixes' as fullID,
round(min(ts)/3600-1800) as bin,
min(ts) as ts,
1 as n,
0 as freq,
0 as sig
from gps where ts between %.14g and %.14g group by round(ts/3600-1800)",
ts[1], ts[2]))
    } else {
        gps = dbGetQuery(recv$con, sprintf("
select 1 as ant,
' GPS Fixes' as fullID,
round(min(t1.ts)/3600-1800) as bin,
min(t1.ts) as ts,
1 as n,
0 as freq,
0 as sig
from gps as t1 join batches as t2 on t1.batchID=t2.batchID where t2.monoBN between %d and %d group by round(t1.ts/3600-1800)",
monoBNlo, monoBNhi))
    }
    gps$fullID = as.factor(gps$fullID)

    ## get pulse counts and reboots to show as status, and append to the dataset
    ## FIXME: if anyone cares, they can recode this in dplyr form
    ## Note that the fullID column must match that used in grepl() in the panel.xyplot function below.

    if (isLotek) {
        ## get pulse counts from the period in question; grab any from batches that overlap
        ## the specified time interval; further filtering happens below

        pulses = dbGetQuery(recv$con, sprintf("
select ant,
' Antenna ' || ant || ' Activity' as fullID,
hourBin as bin,
hourBin * 3600 + 1800 as ts,
1 as n,
0 as freq,
0 as sig
from pulseCounts where hourBin between %.14g and %.14g",
floor(ts[1] / 3600), floor(ts[2] / 3600)))
    } else {
        pulses = dbGetQuery(recv$con, sprintf("
select t1.ant,
' Antenna ' || t1.ant || ' Activity' as fullID,
t1.hourBin as bin,
t1.hourBin * 3600 + 1800 as ts,
1 as n,
0 as freq,
0 as sig
from pulseCounts as t1 join batches as t2 on t1.batchID=t2.batchID where t2.monoBN between %d and %d group by t1.ant, t1.hourBin",
monoBNlo, monoBNhi))
    }
    pulses$fullID = as.factor(pulses$fullID)

    ## get the time of each reboot, again as bogus tags records
    ## Note that the fullID column must match that used in grepl() in the panel.xyplot function below.

    if (! isLotek) {
        reboots = dbGetQuery(recv$con, sprintf("
select monoBN%%10 as ant,
' Reboot Odometer' as fullID,
round(min(tsBegin) / 3600) as bin,
min(tsBegin) as ts,
1 as n,
0 as freq,
0 as sig
from batches where monoBN between %d and %d and tsBegin >= 1262304000 group by monoBN",
monoBNlo, monoBNhi))
        reboots$fullID = as.factor(reboots$fullID)
    } else {
        reboots = NULL
    }
    tags = rbind(tags, pulses, gps, reboots)

    ## filter out anything with an invalid (pre-GPS) date, or a date in the future
    NOW = as.numeric(Sys.time())

    tags = tags %>% filter_(~ts >= MOTUS_SG_EPOCH & ts <= NOW)

    class(tags$ts) = c("POSIXt", "POSIXct")

    dayseq = seq(from=round(min(tags$ts), "days"), to=round(max(tags$ts),"days"), by=24*3600)

    ylab = paste0("Full Tag ID", ylabExtra)
    numTags = length(unique(tags$fullID))
    width = 500 + 7 * length(dayseq)  ## 7 pixels per day plus margins
    height = 315 + 20 * numTags + heightExtra  ## 20 pixels per tag line plus margins
    dateLabel = sprintf("Date (GMT)\n%s", paste(format(range(tags$ts), "%Y-%b-%d %H:%M"), collapse=" to "))
    dateLabel = paste0(dateLabel, xlabExtra)
    plot = xyplot(
        fullID~ts,
        groups = ant, data = tags,
        panel = function(x, y, groups, ...) {
            panel.abline(h=unique(y), lty=2, col="gray")
            panel.abline(v=dayseq, lty=3, col="gray")
            ant = grepl("^ Antenna", y, perl=TRUE)    ## must match fullID formatting from dbGetQuery above
            boot = grepl("^ Reboot", y, perl=TRUE)    ## ...
            gps = grepl("^ GPS", y, perl=TRUE)        ## ...
            tag = ! (ant | boot | gps)
            ## plot reboots
            if (any(boot))
                panel.xyplot(x[boot], y[boot], groups=groups[boot], pch = as.character(levels(as.factor(groups[boot]))), col="black", ...)
            ## plot gps fix times
            if (any(gps))
                panel.xyplot(x[gps], y[gps], groups=groups[gps], pch = "|", col="green", ...)
            ## plot antennas
            if (any(ant))
                panel.xyplot(x[ant], y[ant], groups=groups[ant], pch = '|', col = antCol[1 + as.integer(levels(as.factor(groups[ant])))], ...)
            ## plot tags
            if (any(tag))
                panel.xyplot(x[tag], y[tag], groups=groups[tag], col = antCol[1 + as.integer(levels(as.factor(groups[tag])))], ...)
        },
        main = list(paste0(title, "\n", sprintf("Receiver: %s", serno)), cex=1.5),
        ylab = list(ylab, cex=1.5),
        xlab = list(dateLabel, cex=1.5),
        cex = 1.5,
        scales=list(cex = 1.5)
        )

    return (list(
        width = width,
        height = height,
        plot = plot,
        data = tags
        ))
}
