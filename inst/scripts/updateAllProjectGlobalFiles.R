#!/usr/bin/Rscript

._(` (

   updateAllProjectGlobalFiles.R

Generate the global tags files and summary plots for every project
in a given year.

Call this script as so:

  updateAllProjectGlobalFiles.R [YEAR]

If YEAR is not specified, use the current year, minus 90 days, to reflect
the "current" field year.

._(` )

ARGS = commandArgs(TRUE)
PATH = getwd()

library(lubridate)

YEAR = as.integer(ARGS[1])
if (is.na(YEAR)) {
    YEAR = year(Sys.time() - 90 * 24 * 3600)  ## year 3 months ago (start of 'current' field season)
} else if (YEAR < 2011) {
    stop("Invalid YEAR specified:", YEAR)
}

setwd(sprintf("/SG/contrib/%d", YEAR))

PROJS = dir(".")

## drop names which are not project directories

PROJS = PROJS[file.info(PROJS)$isdir & file.exists(file.path(PROJS, "PROJCODE.TXT"))]

for (p in PROJS) {
    cat("Doing ", p, "\n")
    system(sprintf("/SG/code/plot_global_tags.R '%s' %d; /SG/code/attach_project_files_to_wiki.R '%s'", p, YEAR, p))
}

    
