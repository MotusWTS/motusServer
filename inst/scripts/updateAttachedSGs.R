#!/usr/bin/Rscript

## ._(` (
## update_attached_SGs.R [MATCH]

## For any remote SG with a live connection to the server, download any
## new/changed files and re-run tag finding and distribution.
## This script can be run from a crontab, but probably shouldn't
## be run too often (hourly is fine) as re-running the tag finder currently
## causes all raw data from a site to be re-run, which is obviously
## massive overkill (the current boot session would be sufficient).
## FIXME: we need checkpointing on the tagfinder, so it can be paused
## and restarted when new data arrive.

## If MATCH, a regular expression, is specified, only the SGs whose serial number,
## port number matches the regexp is processed.  Otherwise, all attached SGs are
## processed.

## Call this script as so:

##   update_attached_SGs.R [MATCH]


## ._(` )

options(error=dump.frames)

LOGFILENAME = "/sgm/logs/online_site_updates.log.txt"
logfile = file(LOGFILENAME, "a")
sink(logfile)
sink(logfile, type="message")

cat("Running update_attached_SGs.R at ", format(Sys.time()), "\n")

library(dplyr)
library(RSQLite)
MATCH = commandArgs(TRUE)
## get dataframe of attached receivers
ports = system("/sgm/bin/sgwho.R", intern=TRUE) %>%
    grep(pattern=",4[0-9]{4},", value=TRUE, perl=TRUE) %>%
        textConnection %>%
            read.csv(as.is=TRUE, header=FALSE)

if (nrow(ports) == 0)
    stop("No receivers connected")

names(ports) = c("serno", "port", "projSite")

if (length(MATCH) > 0) {
    ports = ports[grepl(MATCH, paste(ports$serno, ports$port), perl=TRUE),]
    if (nrow(ports) == 0)
        stop("no receivers match specified expression")
}

## master table of sites, serial numbers
## looking for tags from current/previous season:
YEAR = format(Sys.time() - 3 * 30 * 24 * 3600, "%Y")
## looking for tags out now
YEAR = format(Sys.time(), "%Y")
cat("Looking up receivers by serial number in file ", sprintf("/SG/%s_receiver_serno.sqlite", YEAR), "\n")
recv = src_sqlite(sprintf("/SG/%s_receiver_serno.sqlite", YEAR)) %>%
    tbl("map") %>% as.data.frame

con = dbConnect(RSQLite::SQLite(), ":memory:")
dbWriteTable(con, "recv", recv)

## left join trick to get latest row (largest tsHi) for each receiver
recv = dbGetQuery(con, "select t1.* from recv as t1 left outer join recv as t2 on t1.Serno=t2.Serno and t1.tsHi < t2.tsHi where t2.Serno is null")
dbDisconnect(con)

for (i in 1:nrow(ports)) {
    sn = ports$serno[i]
    j = which(recv$Serno == sn)
    if (length(j) == 0) {
        warning("No known site with receiver", sn)
        next
    }
    if (sn == "SG-5113BBBK3084") {
        warning("skipping Formosa2")
        next
    }
    ## if (sn == "SG-5113BBBK3100") {
    ##     warning("skipping Waterford")
    ##     next
    ## }

    ## if (sn == "SG-3214BBBK1004") {
    ##     warning("skipping Reeds")
    ##     next
    ## }

    if (sn == "SG-5113BBBK3157") {
        warning("skipping Pointe Noire")
        next
    }

    ## update the site corresponding to the attached
    ## receiver; do this as a background job, so that
    ## we can start rsync on each attached receiver,
    ## without waiting for (possibly slow) processing
    ## of downloaded data
    
    cmd = sprintf("/SG/code/update_site.R -i %d %s %s %s >> %s 2>&1",
            ports$port[i],
            recv$Site[j],
            recv$Project[j],
            YEAR,
            LOGFILENAME
            )
    cat("Running:", cmd, "\n")
    system(cmd)

}
