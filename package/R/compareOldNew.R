#' compare new-style tag-finder results with the traditional approach
#'
#' Plot a Year/Project/Site tag detection plot (condensed to first detection
#' of each tag per hour), overplotting detections by old and new methods.
#'
#' @param year - integer year
#'
#' @param proj - sensorgnome project code
#'
#' @param site - sensorgnome site code
#'
#' @param oldSym - plot symbol for old detections; default:  25 (downward triangle)
#'
#' @param newSym - plot symbol for new detections; default: 24 (upward triangle)
#'
#' @return a character vector of full paths to any files created (plots, datasets)
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

compareOldNew = function(year, proj, site, oldSym = 25, newSym = 24) {
    rv = character(0)

    f = sprintf("/SG/contrib/%d/%s/%s/%d_%s_%s_alltags.sqlite", year, proj, site, year, proj, site)
    dbf = sub("_alltags", "", f)

    ylo = as.numeric(ymd_h(paste(year, 1, 1, 1, sep="-")))
    yhi = as.numeric(ymd_h(paste(year + 1, 1, 1, 1, sep="-")))

    ## get old dataset from either .rds or .sqlite files:

    if (! file.exists(f)) {
        f = sub(".sqlite$", ".rds", f)
        if (! file.exists(f))
            stop("Non-existent combination: ", year, proj, site)
        old = readRDS(f)
        if (length(old) == 0 || nrow(old) == 0)
            stop("No tags in: ", year, proj, site)
        old$ts = as.numeric(old$ts)
        old$fullID = as.character(old$fullID)
        old$ant = as.integer(as.character(old$ant))
        old = old %>% as.tbl
        told = old %>% mutate(hourBin=round(ts/3600-0.5, 0)) %>% group_by(recv, ant, fullID, hourBin) %>%
        filter_ (~runLen >= 3 & (is.na(freqsd) | freqsd < 0.1) & ts >= ylo & ts <= yhi) %>%
        summarize(n=length(ts), ts=min(ts), freq=mean(freq), sig=max(sig)) %>%
        collect %>% as.data.frame
    } else {
        src = src_sqlite(f)
        if (! "tags" %in% src_tbls(src))
            stop("Database has no tags table for: ", year, proj, site)
        old = tbl(src, "tags")
        if (old %>% head(1) %>% collect %>% nrow != 1)
            stop("No tag detections for: ", year, proj, site)
        told = old %>% mutate(hourBin=round(ts/3600-0.5, 0)) %>% group_by(recv, ant, fullID, hourBin) %>%
        filter_ (~runLen >= 3 & (is.na(freqsd) | freqsd < 0.1) & ts >= ylo & ts <= yhi) %>%
        summarize(n=length(ts), ts=min(ts), freq=avg(freq), sig=max(sig)) %>%
        collect %>% as.data.frame
        ## if (told %>% head(1) %>% collect %>% nrow != 1)
        ##     stop("No filtered tag detections for: ", year, proj, site, "\nPerhaps receiver clock was not correctly set?")
    }

    n2014map = list(
        "ASmith"  = "AdamSmith",
        "Dosmn"   = "Dossman",
        "Hamil"   = "Hamilton",
        "Holbt"   = "HolbSESA",
        "Lorng"   = "Loring",
        "Protandry"  = "Morbey",
        "Peter"   = "Peterson",
        "Salda"   = "Saldanha",
        "Taylr"   = "Taylor"
    )

    for (old in names(n2014map))
        told$fullID = sub(old, n2014map[[old]], told$fullID, fixed=TRUE)

    told$new = rep(FALSE, nrow(told))

    ## generate physID of form ID:BI@FREQ

    told$physID = stri_replace_all_regex(told$fullID, "(.*)#(.*)@(.*):(.*)", "$2:$4@$3")

    ## re-arrange components of fullID to: ID:BI#PROJ@FREQ

    told$fullID = stri_replace_all_regex(told$fullID, "(.*)#(.*)@(.*):(.*)", "$2:$4#$1@$3")

    ## for each receiver in the old form site database, get the serial
    ## number and range of dates.  A site in a given year might have used
    ## several different receivers.  A single receiver might appear in
    ## the deployments table multiple times, once for each different
    ## file prefix set by the user via the "shortLabel" field in deployment.txt

    olds = src_sqlite(dbf)
    oldrec = tbl(olds, "deployments") %>%
        left_join( tbl(olds, "files"), by="depID") %>%
        filter(ts >= 1262304000) %>%
        group_by(recv) %>%
        summarize(tsLo = min(ts), tsHi = max(ts) + 3600) %>%
        as.data.frame

    allnew = NULL
    for (i in seq(length = nrow(oldrec))) {
        newf = paste0("/sgm/recv/SG-", oldrec$recv[i], ".motus")

        if (! file.exists(newf)) {
            warning("No new-style database for receiver ", r)
            next
        }
        ## get the numeric range of timestamps for this year
        ## and truncate to year boundaries

        trange = c(max(ylo, oldrec$tsLo[i]), min(yhi, oldrec$tsHi[i]))

        src = src_sqlite(newf)
        mot = getMotusMetaDB()

        tnew = tagview(src, mot)

        ## look at only the first detection of each tag per hour
        tnew = tnew %>% filter_(~is.na(freqsd) | freqsd < 0.1) %>% mutate(hourBin = round(ts/3600-0.5, 0)) %>% group_by(ant, fullID, hourBin) %>%
            filter_ (~ts >= trange[1] & ts <= trange[2]) %>%
            summarize(ts=min(ts), n=length(ts), freq=avg(freq), sig=max(sig)) %>%
            collect %>% as.data.frame

        ## add recv column
        if (tnew %>% head(1) %>% collect %>% nrow > 0) {
            tnew$recv = oldrec$recv[i]
            tnew$new = TRUE
        }

        allnew = rbind(allnew, tnew)
    }
    fixup = which(grepl(".0@", allnew$fullID, fixed=TRUE))
    allnew$fullID[fixup] = sub(".0@", "@", allnew$fullID[fixup], fixed=TRUE)

    ## re-arrange components of fullID to: ID:BI#PROJ@FREQ
    allnew$physID = stri_replace_all_regex(allnew$fullID, "(.*)#(.*):(.*)@(.*)", "$2:$3@$4")

    ## re-arrange components of fullID to: ID:BI#PROJ@FREQ
    allnew$fullID = stri_replace_all_regex(allnew$fullID, "(.*)#(.*):(.*)@(.*)", "$2:$3#$1@$4")

    all = rbind(told, allnew)
    class(all$ts) = c("POSIXt", "POSIXct")


    dayseq = seq(from=round(min(all$ts), "days"), to=round(max(all$ts),"days"), by=24*3600)

    datafilename = sprintf("/sgm/plots/%d_%s_%s_hourly_old_new.rds", year, proj, site)
    saveRDS(all, datafilename)

    ## plot twice, once using fullID, once using physID
    phys = "" ## extra component for plot file name
    ylab = "FullID\n(project names might differ between old and new)"
    repeat {
        numTags = length(unique(all$fullID))  ## compute separately for each plot
        plotfilename = sprintf("/sgm/plots/%d_%s_%s_%shourly_old_new.png", year, proj, site, phys)
        png(plotfilename, width=1024, height=300 + 20 * numTags, type="cairo-png")
        rv = c(rv, plotfilename)
        dateLabel = sprintf("Date (%s, GMT)", dateStem(all$ts[c(1, nrow(all))]))

        print(xyplot(as.factor(fullID)~ts,
                     groups = new, data = all,
                     panel = function(x, y, groups) {
                         panel.abline(h=unique(y), lty=2, col="gray")
                         panel.abline(v=dayseq, lty=3, col="gray")
                         panel.xyplot(x, y, pch = ifelse(groups, newSym, oldSym), col = ifelse(groups, 2, 1), cex=2)
                     },
                     auto.key = list(
                         title="Data Source",
                         col=c(2, 1), points=FALSE, text=c("new: ^", "old: v")
                     ),
                     main = sprintf("%d %s %s Hourly Tags; Old vs. New data processing", year, proj, site),
                     sub = sprintf("Receiver(s): %s", paste0("SG-", oldrec$recv, collapse=",")),
                     ylab = ylab,
                     xlab = dateLabel
                     )
              )
        dev.off()
        if (phys != "")
            break
        phys="physID_"
        ylab = "physical ID (no project code)"
        all$fullID = all$physID
    }
    rv = c(rv, datafilename)
    return(rv)
}
