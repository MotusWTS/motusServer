#!/usr/bin/Rscript
##
## rerun an uploaded job from scratch
##

ARGS = commandArgs(TRUE)

if (length(ARGS) == 0) {
    cat("
Usage: rerunUploadJob.R JOBNO

where:

 JOBNO: job number, as seen on the My Job Status page.

Rerun a job from the archived copy of the uploaded file(s),
as if it had never been run before.  The original job and
its subjobs are wiped from history.

A new job will be created and placed into the master queue (queue 0),
from where a processServer can claim it.

FIXME
=====
Features *not* yet implemented by this script:

  - delete or revert batches in receiver DBs that were created or
    appended to by the original job run

  - add deleteBatch records to the motus transfer tables in
    the same situation.
")

    q(save="no", status=1)
}

job = as.integer(ARGS[1])

suppressMessages(suppressWarnings(library(motusServer)))

## set up the jobs structure

loadJobs()

if (rerunUploadJob(Jobs[[job]])) {
    cat("Rerun of files uploaded for job", job, "has been queued.\n")
} else {
    cat("There was an error; perhaps there is no job #", job, "?\n")
}
