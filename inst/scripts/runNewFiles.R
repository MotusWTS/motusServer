#!/usr/bin/Rscript
##
##
## Run a folder of new files as if they had been submitted via email.
##

ARGS = commandArgs(TRUE)

if (length(ARGS) == 0) {
    cat("

Usage: runNewFiles.R [-p] DIR

where:

 DIR: path to the folder containing new files

 -p:  preserve the original files.  A new folder with either hardlinks to
  the original files (when on the same filesystem as the folder /sgm) or
  copies of the original files (when on a different filesystem) is created,
  and that folder is run instead of DIR.

A new job with type 'newFiles' will be created and placed into the master queue (queue 0),
from where a processServer can claim it.  The sender will be: ",

MOTUS_ADMIN_EMAIL,
"\n"
)
    q(save="no", status=1)
}

preserve = FALSE

while(isTRUE(substr(ARGS[1], 1, 1) == "-")) {
    switch(ARGS[1],
           "-p" = {
               preserve = TRUE
           },
           {
               stop("Unknown argument: ", ARGS[1])
           })
    ARGS = ARGS[-1]
}

DIR=ARGS[1]
suppressMessages(suppressWarnings(library(motusServer)))

## create and enqueue a job to process the new files

loadJobs()

j = newJob("newFiles", .parentPath=MOTUS_PATH$INCOMING, replyTo=MOTUS_ADMIN_EMAIL, .enqueue=FALSE)

## move, hardlink, or copy files to the job's dir

if (! preserve) {
    ## just move the files to the new job's folder
    moveFiles(DIR, j$path)
} else {
    ## we need to leave existing files alone
    ## try hardlink, and if that fails, copy
    if (! lightWeightCopy(DIR, j$path)) {
        stop("Failed to make a lightweight copy of ", DIR)
    }
}

## move the job to the top-level processServer queue

j$queue = 0
moveJob(j, MOTUS_PATH$QUEUE0)

cat("Job", unclass(j), "has been entered into queue 0\n")
