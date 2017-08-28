#!/usr/bin/Rscript
##
## Retry a job that had errors.
##

ARGS = commandArgs(TRUE)

if (length(ARGS) == 0) {
    cat("

Usage: retryJob.R jobID

where:

 jobID: integer job ID of a job that had errors.

If jobID is the ID of a job that had errors, a record of the
errors is added to the log, and the 'done' code for those
subjobs with errors is set to 0.

The job is then moved to  queue 0, where it can be claimed
by a running processServerl, which will re-attempt all
failed subjobs in order.

")

    q(save="no", status=1)
}

jobID = as.integer(ARGS[1])

if (is.na(jobID))
    stop("You must specify a job number.")

suppressMessages(suppressWarnings(library(motusServer)))

loadJobs()

j = Jobs[[jobID]]

if (is.null(j))
    stop(jobID, " is not a valid jobID")

done = children(j)$done

if (all(done > 0))
    stop("All subjobs of Job ", jobID, " completed successfully")

## mark jobs with errors as not done

kids = children(j)[done < 0]  ## need to end up with a LHS object of
                              ## class "Twig" for the subsequent
                              ## assignment
kids$done = 0

msg = sprintf("Retrying subjob(s) %s of types %s", paste(kids, collapse=", "), paste(kids$type, collapse=", "))
jobLog(j, msg, summary=TRUE)
jobLog(j, "--- (retry) ---")

moveJob(j, MOTUS_PATH$QUEUE0)

cat("\n", msg, " for job ", j, "\n")
