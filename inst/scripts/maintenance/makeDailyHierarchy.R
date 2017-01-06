#!/usr/bin/Rscript

# makeDailyHierarchy.R - parse SG files in a folder, create a daily
# subfolder for each distinct day with form YYYY-MM-DD, and move files
# to their appropriate subfolder

suppressWarnings(suppressMessages(library(motusServer)))  ## for parseFilenames
options(warn=1)

ARGV = commandArgs(TRUE)

for (DIR in ARGV) {

    d = dir(DIR, full.names=TRUE)
    d = d[! file.info(d)$isdir]

    if (length(d) == 0) {
        warning("No files to move for ", DIR)
        next
    }
    p = parseFilenames(d)

    p$day = format(p$ts, "%Y-%m-%d")

    ## create dirs
    for (day in unique(p$day))
        dir.create(file.path(DIR, day))

    all(file.rename(d, file.path(DIR, p$day, basename(d))))
    cat("Moved", length(d), "files for", DIR)
}
