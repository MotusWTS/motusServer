#!/usr/bin/Rscript
##
##
## Reprocess raw data from a receiver.
##

ARGS = commandArgs(TRUE)

if (length(ARGS) == 0) {
    cat("

Usage: rerunReceiver.R [-d] [-e] SERNO [BLO BHI]

where:

 SERNO: receiver serial number; e.g. SG-0613BB000613 or Lotek-123

 BLO BHI: for an SG, you can specify a range of boot sessions by specifying
 BLO and BHI as the low and high boot sessions, respectively;
 for Lotek receivers, all raw data are reprocessed

 -e: don't re-run the tag finder; just re-export data

 -d: before running the tag finder, delete existing batches, runs, hits for
     the specified boot sessions

A new job will be created and placed into the master queue (queue 0),
from where a processServer can claim it.

")

    q(save="no", status=1)
}

exportOnly = FALSE
cleanup = FALSE
monoBN = NULL

while(isTRUE(substr(ARGS[1], 1, 1) == "-")) {
    switch(ARGS[1],
           "-e" = {
               exportOnly = TRUE
           },
           "-c" = {
               cleanup = TRUE
           },
           {
               stop("Unknown argument: ", ARGS[1])
           })
    ARGS = ARGS[-1]
}

serno = ARGS[1]
if (is.na(serno)) stop("You must specify a receiver serial number.")

ARGS = ARGS[-1]

if (length(ARGS) > 0) {
    monoBN = range(as.integer(ARGS))
}

suppressMessages(suppressWarnings(library(motus)))

## set up the jobs structure

loadJobs()

j = newJob("rerunReceiver", .parentPath=MOTUS_PATH$INCOMING, serno=serno, monoBN=monoBN, exportOnly=exportOnly, cleanup=cleanup, .enqueue=FALSE)

## move the topJob to the top-level processServer queue

j$queue = 0
moveJob(j, MOTUS_PATH$QUEUE0)

cat("Job", unclass(j), "has been entered into queue 0\n")
