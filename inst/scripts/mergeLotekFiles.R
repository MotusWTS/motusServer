#!/usr/bin/Rscript

._(` (
   mergeLotekFiles.R DIR [RECVDBDIR]

Add any Lotek .DTA files in folder DIR and its subfolders to the appropriate
receiver database(s), which are stored in RECVDBDIR.

By default, RECVDBDIR is /sgm/recv, and receiver databases there
have names like  SRX-DL-8203.motus

A summary data.frame of file properties is written to an rds file in DIR

._(` )

ARGS = commandArgs(TRUE)

suppressMessages(suppressWarnings(library(motus)))

DIR       = ARGS[1]
RECVDBDIR = ARGS[2]

if (is.na(RECVDBDIR))
    RECVDBDIR = "/sgm/recv"

res = ltMergeFiles(RECVDBDIR, DIR)

cat("Summary of file properties:\n")

msg = res %>% summarize(
            "Filename_new" = sum(nameNew),
            "Data_new" = sum(dataNew),
            "Data_used" = sum(use),
            "Errors" = sum(! is.na(err))
        ) %>% as.matrix
msg

saveRDS(res %>% as.data.frame, file.path(DIR, paste0("mergeLotekfiles", format(Sys.time(),"%Y-%m-%dT%H-%M-%S"), "_log.rds")))
