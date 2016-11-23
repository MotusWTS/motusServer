#!/usr/bin/Rscript
##
##
## Reprocess raw data from a receiver.
##

ARGS = commandArgs(TRUE)

if (! length(ARGS) %in% c(1, 3)) {
    cat("

Usage: rerunReceiver.R SERNO [BLO BHI]

 - for Lotek receivers, all raw data are reprocessed

 - for an SG, you can specify a range of boot sessions by specifying BLO and BHI
   as the low and high boot sessions, respectively.

A new job will be created and placed into the master queue (queue 0),
from where a processServer can claim it.

")

    q(save="no", status=1)
}


suppressMessages(suppressWarnings(library(motus)))

## set up the jobs structure

loadJobs()

j = newJob("rerunReceiver", .parentPath=MOTUS_PATH$INCOMING, serno=ARGS[1], .enqueue=FALSE)

if (length(ARGS) == 3) {
    j$monoBN = as.integer(ARGS[-1])
}

## move the topJob to the top-level processServer queue

j$queue = 0
moveJob(j, MOTUS_PATH$QUEUE0)

cat("Job", unclass(j), "has been entered into queue 0\n")
