#!/usr/bin/Rscript

ARGV = commandArgs(TRUE)

if (length(ARGV) == 0) {
    cat("
Make sure all data files in a receiver's DB are in the file repo,
adding any which are missing, and backing up any which get replaced
by a longer version from the DB.

Usage:

   syncDBtoFiles SERNO [ RECVDIR [ REPODIR [ BKUPDIR ] ] ]

where:

   SERNO - receiver serial number; e.g. SG-1234BBBK2345 or Lotek-1234

   RECVDIR - folder where receiver databases are; default: /sgm/recv

   REPODIR - folder where file repo is; default: /sgm/file_repo

   BKUPDIR - folder to store backups of updated files; default: /sgm/trash

");
    q(save="no")
}

SERNO = ARGV[1]
RECVDIR = ifelse (is.na(ARGV[2]), "/sgm/recv", ARGV[2])
REPODIR = ifelse (is.na(ARGV[3]), "/sgm/file_repo", ARGV[3])
BKUPDIR = ifelse (is.na(ARGV[4]), "/sgm/trash", ARGV[4])

if (! file.exists(file.path(RECVDIR, paste0(SERNO, ".motus"))))
    stop("No receiver database found")

suppressWarnings(suppressMessages(library(motusServer)))
x = syncDBtoFiles(SERNO, RECVDIR, REPODIR, BKUPDIR)

tx = table(x$status)

cat("Files already present and complete: ", tx["0"], "\n")
cat("Files already present, but incomplete so backed-up and updated: ", tx["1"], "\n")
cat("New files: ", tx["2"], "\n")
