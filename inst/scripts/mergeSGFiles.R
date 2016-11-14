#!/usr/bin/Rscript

._(` (
   mergeSGFiles.R DIR [RECVDBDIR]

Add any raw sensorgnome data files in folder DIR and
its subfolders to the appropriate receiver database(s),
which are stored in RECVDBDIR.

By default, RECVDBDIR is /sgm/recv, and receiver databases there
have names like  SG-1012BB012090.motus

A summary data.frame of file properties is written to an rds file in DIR

._(` )

ARGS = commandArgs(TRUE)

suppressMessages(suppressWarnings(library(motus)))

MOTUS_SERVER_DB_SQL <<- ensureServerDB()
MOTUS_PROCESS_NUM <<- 100 ## needed by lockReceiver

DIR       = ARGS[1]
RECVDBDIR = ARGS[2]

if (is.na(RECVDBDIR))
    RECVDBDIR = "/sgm/recv"

res = sgMergeFiles(DIR, RECVDBDIR)

if (is.null(res)) {
    cat("No SG data files found in", DIR, "\n")
} else {
    cat("Summary of file properties from", DIR, ":\n")

    msg = res$info %>% summarize(
                      "Had_new_data" = sum(use),
                      "Not_seen_before" = sum(new),
                      "Now_complete" = sum(done),
                      "Corrupt_compressed" = sum(corrupt),
                      "Shorter_than_existing" = sum(small),
                      "Partial" = sum(partial)
                  ) %>% as.matrix
    msg = cbind(msg, "Not_SG_File" = attr(res, "nbadfiles"))
    print(msg)

    saveRDS(res$info %>% as.data.frame, file.path(DIR, paste0("mergeSGfiles", format(Sys.time(),"%Y-%m-%dT%H-%M-%S"), "_log.rds")))
}
