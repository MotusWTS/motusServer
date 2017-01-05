#!/usr/bin/Rscript
##
##
## Run a folder of new files as if they had been submitted via email.
##

suppressMessages(suppressWarnings(library(motusServer)))

ARGS = commandArgs(TRUE)

if (length(ARGS) == 0) {
    cat("

Usage: runNewFiles.R [-p] [-n|-l] [-m] [-s] DIR

where:

 DIR: path to the folder containing new files

 -p: if specified, run on one of the priority processServers, jumping
  the queue ahead of any uploaded data jobs

 -l: symlink to the new files; create a new folder with symlinks to
  all files in the original folder

 -n: don't preserve the original files.  Without this option, a new
  folder with either hardlinks to the original files (when on the same
  filesystem as the folder /sgm) or copies of the original files (when
  on a different filesystem) is created, and that folder is run
  instead of DIR.  With the '-n' option, the original files are moved.
  This option is ignored if -l is specified.

 -m: merge files into databases, but do not run the tagfinder.

 -s: sanity check files; the sanity check is slow, because each file
  is checked to see whether it is all zeroes, or an invalid
  archive. This is normally skipped for files already on the server.

A new job with type 'serverFiles' will be created and placed into the
master queue (queue 0), from where a processServer can claim it.  The
sender will be: ",

MOTUS_ADMIN_EMAIL,
"\n"
)
    q(save="no", status=1)
}

priority = FALSE
preserve = TRUE
sanityCheck = FALSE
symLink = FALSE
mergeOnly = FALSE

while(isTRUE(substr(ARGS[1], 1, 1) == "-")) {
    switch(ARGS[1],
           "-p" = {
               priority = TRUE
           },
           "-n" = {
               preserve = FALSE
           },
           "-s" = {
               sanityCheck = TRUE
           },
           "-m" = {
               mergeOnly = TRUE
           },
           "-l" = {
               symLink = TRUE
           },
           {
               stop("Unknown argument: ", ARGS[1])
           })
    ARGS = ARGS[-1]
}

DIR=ARGS[1]

## create and enqueue a job to process the new files

loadJobs()

j = newJob("serverFiles", .parentPath=MOTUS_PATH$INCOMING, replyTo=MOTUS_ADMIN_EMAIL, valid=TRUE, sanityCheck=sanityCheck, .enqueue=FALSE, mergeOnly=mergeOnly)
jobLog(j, paste0("Merging new files from server directory ", DIR))
## move, hardlink, or copy files to the job's dir

if (! preserve) {
    ## just move the files to a new subfolder of the new job's folder
    newdir = file.path(jobPath(j), "files")
    dir.create(newdir)
    moveDirContents(DIR, newdir)
} else {
    ## we need to leave existing files alone
    ## try hardlink, and if that fails, copy
    if (! lightWeightCopy(DIR, jobPath(j), sym=symLink)) {
        stop("Failed to make a lightweight copy of ", DIR)
    }
}

## move the job to the queue 0 or the priority queue

j$queue = "0"  ## this is a marker for claiming the job, not really the queue value, so fine for PRIORITY jobs too

if (priority) {
    moveJob(j, MOTUS_PATH$PRIORITY)
    cat("Job", unclass(j), "has been entered into the priority queue\n")
} else {
    moveJob(j, MOTUS_PATH$QUEUE0)
    cat("Job", unclass(j), "has been entered into queue 0\n")
}
