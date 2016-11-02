#!/usr/bin/Rscript

suppressMessages(suppressWarnings(library(motus)))

## parameters for the tag finder
## Note the use of the '-e' parameter, to force tag deployment events to be
## used (i.e. start looking for a tag on the date it's deployed; stop looking
## after its expected or known lifetime).

PARS = sgDefaultFindTagsParams
LOTEKPARS = ltDefaultFindTagsParams

._(` (
   runReceiver.R [--vacuum] [--no-motus] RECVDB [ PARS ]

Do a clean run of the tag finder on the entire dataset
from the specified receiver database.
RECVDB is the path to a receiver .motus database, e.g. SG-1234BBBK5678.motus

If --vacuum is specified, re-compress the full database before running the tag finder.

If --motus is specified, send results to the motus transfer table.

PARS is an optional set of command-line parameters for the find_tags_motus program,
which override the defaults.

._(` )

ARGS = commandArgs(TRUE)

if (length(ARGS) == 0) {
  ._SHOW_INFO()
  quit(save="no")
}


VACUUM = FALSE


if (ARGS[1] == "--vacuum") {
    VACUUM = true
    ARGS = ARGS[-1]
}

MOTUS = TRUE
if (ARGS[1] == "--no-motus") {
    MOTUS = FALSE
    ARGS = ARGS[-1]
}

RECVDB = ARGS[1]
if (! file.exists(RECVDB))
    stop("No such receiver database: ", RECVDB)

## paste any additional parameters to allow overriding defaults
PARS = paste(PARS, paste(ARGS[-1], collapse=" "))
LOTEKPARS = paste(LOTEKPARS, paste(ARGS[-1], collapse=" "))

realReceiver = basename(system(paste("readlink", RECVDB), intern=TRUE))
recvPageName = sub(".motus$", "", realReceiver)

system(sprintf("/SG/code/wiki_create_page.R sensorgnome Internal_Pages/Receivers %s", recvPageName))
recvPagePath = sprintf("Internal_Pages/Receivers/%s", recvPageName)

logfilename = paste0("/sgm/logs/", sub(".motus$", "", realReceiver), ".log.txt")
logfile = file(logfilename, "a")
sink(logfile)
sink(logfile, type="message")

cat(format(Sys.time()), "------ START runReceiver.R ------------------\n")

s = src_sqlite(RECVDB)
meta = getMap(s, "meta")

## do a full cleanup
cat("Cleaning up old runs...\n")

cleanup(s, TRUE, VACUUM)
recordEvent("CLEAN", "sensorgnome.org:runReceiver.R", meta$recvSerno)

## ensure we are working with a recent, cleaned-up copy of the motus tag database
cat("Grabbing the cleaned-up tag registration database...\n")

mot = getMotusMetaDB()

## run the tag finder
cat("Running the tag finder...\n")

## Note: use resume=FALSE to avoid scrambled history
## arising from monoBN not really being monotonic in time.
## (i.e. some batches with lower monoBN are actually later than
## those with higher monoBN.  Resuming the tag event history
## in this case would lead to it being incorrect, since the
## data stream is assumed to be in increasing order by time.)

if (meta$recvType == "Lotek") {
    ltFindTags(s, mot, par=LOTEKPARS)
} else {
    sgFindTags(s, mot, par=PARS, resume=FALSE)
}

logURL =  system(sprintf("/SG/code/wiki_attach.R sensorgnome %s %s", recvPagePath, logfilename), intern=TRUE)
recordEvent("FINDTAGS", "sensorgnome.org:runReceiver.R", meta$recvSerno, 0, URLs=logURL, URLlabels=logfilename)

## push data to motus transfer tables
if (MOTUS) {
    cat("Copying data to motus transfer tables...\n")
    try ({
        pushToMotus(s)
    })
}

## list of files to attach to receiver wiki page

att = logfilename
## if this receiver database was referred to by a YEAR_PROJ_SITE symlink,
## plot a comparison of old and new style detections

parts = strsplit(basename(RECVDB), "_")[[1]]
if (length(parts) >= 3) {
    cat("Plotting comparison between old and new results.\n")
    site = paste0(parts[-(1:2)], collapse="_")
    site = sub("-[0-9]+$", "", site, perl=TRUE)
    att = c(att, compareOldNew(year=as.integer(parts[1]), proj=parts[2], site=site))
}

cat(format(Sys.time()), "------ END   runReceiver.R ------------------\n")


## attach output files to wiki, recording URLs
URLs = sapply(att,
              function(a) {
                  system(sprintf("/SG/code/wiki_attach.R sensorgnome %s %s", recvPagePath, a), intern=TRUE)
              })
recordEvent("COMPAREOLDNEW", "sensorgnome.org:runReceiver.R", meta$recvSerno, 0, URLs=URLs, URLlabels=att)
