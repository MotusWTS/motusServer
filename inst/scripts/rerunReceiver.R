#!/usr/bin/Rscript
##
##
## Reprocess raw data from a receiver.
##

ARGS = commandArgs(TRUE)

if (length(ARGS) == 0) {
    cat("

Usage: rerunReceiver.R [-F] [-p] [-c] [-e] [-t] [-P PROJECTID] [-U USERID] SERNO [BLO BHI]

where:

 SERNO: receiver serial number; e.g. SG-0613BB000613 or Lotek-123
 [PROJECTID]: integer ID of motus project which should own products
 (will be overridden by receiver deployment records, where these exist)
 [USERID]: integer ID of motus user who initiated the rerun

 BLO BHI: for an SG, you can specify a range of boot sessions by specifying
 BLO and BHI as the low and high boot sessions, respectively;
 for Lotek receivers, all raw data are reprocessed

 -p: run the job at high priority, on one of the processServers dedicated
     to short, fast jobs; this jumps the queue of processing uploaded data.

 -P PROJECTID: specify integer ID of motus project that will own products; overridden by
     receiver deployment records where these exist

 -U USERID: specify integer ID of motus user who is submitting this job

 -e: don't re-run the tag finder; just re-export data

 -c: cleanup: before running the tag finder, delete existing batches, runs, hits for
     the specified boot sessions

 -F: full rerun: delete all internally-stored files before running, then behave
     as if full contents of file_repo for that receiver consists of new files

 -t: mark job output as `isTesting`; data from such batches will only be returned
     for admin users who specify they want to see testing batches.

A new job will be created and placed into the master queue (queue 0),
from where a processServer can claim it.

")

    q(save="no", status=1)
}

priority = FALSE
exportOnly = FALSE
cleanup = FALSE
monoBN = NULL
fullRerun = FALSE
isTesting = FALSE
userID = NULL
projectID = NULL

while(isTRUE(substr(ARGS[1], 1, 1) == "-")) {
    switch(ARGS[1],
           "-p" = {
               priority = TRUE
           },
           "-e" = {
               exportOnly = TRUE
           },
           "-c" = {
               cleanup = TRUE
           },
           "-F" = {
               fullRerun = TRUE
           },
           "-t" = {
               isTesting = TRUE
           },
           "-P" = {
               ARGS = ARGS[-1]
               projectID = as.integer(ARGS[1])
           },
           "-U" = {
               ARGS = ARGS[-1]
               userID = as.integer(ARGS[1])
           },
           {
               stop("Unknown argument: ", ARGS[1])
           })
    ARGS = ARGS[-1]
}

serno = sub("\\.motus$", "", perl=TRUE, ARGS[1])
if (is.na(serno)) stop("You must specify a receiver serial number.")

ARGS = ARGS[-1]

if (length(ARGS) > 0) {
    monoBN = range(as.integer(ARGS))
    ARGS = ARGS[-1]
}

suppressMessages(suppressWarnings(library(motusServer)))

## set up the jobs structure

loadJobs()

if (fullRerun) {
    j = newJob("fullRecvRerun", .parentPath=MOTUS_PATH$INCOMING, serno=serno, motusUserID = userID, motusProjectID = projectID, .enqueue=FALSE)
    jobLog(j, paste0("Fully rerunning receiver ", serno, " from file_repo files."), summary=TRUE)
} else {
    j = newJob("rerunReceiver", .parentPath=MOTUS_PATH$INCOMING, serno=serno, monoBN=monoBN, exportOnly=exportOnly, cleanup=cleanup,
                motusUserID = userID, motusProjectID = projectID,
               .enqueue=FALSE)
    jobLog(j, paste0(if(isTRUE(exportOnly)) "Re-exporting data from" else "Rerunning", " receiver ", serno), summary=TRUE)
}

if (isTesting)
   j$isTesting = TRUE

## move the job to the queue 0 or the priority queue

j$queue = "0"

safeSys("sudo", "chown", "sg:sg", j$path)
if (priority) {
    moveJob(j, MOTUS_PATH$PRIORITY)
    cat("Job", unclass(j), "has been entered into the priority queue\n")
} else {
    moveJob(j, MOTUS_PATH$QUEUE0)
    cat("Job", unclass(j), "has been entered into queue 0\n")
}
