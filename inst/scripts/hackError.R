#!/usr/bin/R  < /sgm/bin/hackError.R --interactive
##
## Drop into an R session to examine the stack dump
## of a job with errors.

ARGS = commandArgs(TRUE)
info = "
These variables assigned:

 - j : the job you specified
 - sj: the first subjob of j with an error (if any)
 - sjs: all subjobs of j with an error (if any)
 - bt: the stack dump of the error (if any)
       Simply printing bt gives the names of all but the
       toplevel function involved in the error.
       The toplevel function name is

            paste0('handle', sj$type)

       The calling environments of the function where the
       error occurred can be obtained as bt[[1]], bt[[2]], ...
       so you can do e.g.
            ls(bt[[3]])
            bt[[3]]$files

       The files involved in a job (if any) can be found as
          dir(j$path, recursive=TRUE)
             or
          dir(sj$path, recursive=TRUE)
"

if (length(ARGS) == 0) {
    cat("

Usage: hackError.R jobID

where:

 jobID: integer job ID of a job that had errors, possibly
        among its subjobs.

This starts an R session.

", info)

    q(save="no", status=1)
}

jobID = as.integer(ARGS[1])

if (is.na(jobID))
    stop("You must specify a job number.")

suppressMessages(suppressWarnings(library(motusServer)))

## now that library is loaded, we have MOTUS_PATH

loadJobs()

j = Jobs[[jobID]]

if (is.null(j))
    stop(jobID, " is not a valid jobID")

j = topJob(j)
if (as.numeric(j) != jobID)
    warning("Using topjob ", j, " instead of its descendent ", jobID, "\n")

sjs = progeny(j)
sjs = sjs[sjs$done < 0]
sj = sjs[1]
bt = readRDS(file.path(MOTUS_PATH$ERRORS, sprintf("%08d.rds", sj)))

cat(info)
browser()
