#!/usr/bin/Rscript
##
## Retry a job that had errors.
##

ARGS = commandArgs(TRUE)

if (length(ARGS) == 0) {
    cat("

Usage: retryJob.R [-p] jobID

where:

 jobID: integer job ID of a job that had errors.
 -p: if specified, move the job to a priority queue, rather
     than the usual queue.

If jobID is the ID of a job that had errors, a record of the
errors is added to the log, and the 'done' code for those
subjobs with errors is set to 0.

The job is then moved to  queue 0, where it can be claimed
by a running processServerl, which will re-attempt all
failed subjobs in order.

")

    q(save="no", status=1)
}

if (ARGS[1] == "-p") {
    priority = TRUE
    ARGS = ARGS[-1]
} else {
    priority = FALSE
}

jobID = as.integer(ARGS[1])

if (is.na(jobID))
    stop("You must specify a job number.")

suppressMessages(suppressWarnings(library(motusServer)))

## now that library is loaded, we have MOTUS_PATH

if (priority) {
    queue = MOTUS_PATH$PRIORITY
    queuename = "priority queue"
} else {
    queue = MOTUS_PATH$QUEUE0
    queuename = "normal queue"
}

loadJobs()

j = Jobs[[jobID]]

if (is.null(j))
    stop(jobID, " is not a valid jobID")

j = topJob(j)
if (as.numeric(j) != jobID)
    warning("Using topjob ", j, " instead of its descendent ", jobID, "\n")

done = progeny(j)$done

if (all(done > 0) && j$done > 0)
    stop("All subjobs of Job ", jobID, " completed successfully")

## mark jobs with errors as not done

if (j$done < 0)
    j$done = 0

kids = progeny(j)[done < 0]  ## need to end up with a LHS object of
                              ## class "Twig" for the subsequent
                              ## assignment
kids$done = 0

msg = sprintf("Retrying subjob(s) %s of types %s", paste(kids, collapse=", "), paste(kids$type, collapse=", "))
jobLog(j, msg, summary=TRUE)
jobLog(j, "--- (retry) ---")

tj = topJob(j)
tj$queue = 0L

if (moveJob(tj, queue)) {
    cat("\n", msg, " for job ", j, " using ", queuename, "\n")
} else {
    stop("Failed to move job ", j, " ", queuename, "\n")
}
