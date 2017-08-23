#!/usr/bin/Rscript

ARGV = commandArgs(TRUE)

if (length(ARGV) == 0) {
    cat("
Make sure all data files in a receiver's DB are in the file repo,
adding any which are missing, and backing up any which get replaced
by a longer version from the DB.  The results are written
as a .csv (tab-separated) sequence of (filename, status),
where status is an integer meaning:

0: no change; file already in repo and contains the same or longer data as in DB
1: updated; file already in repo, but DB had a longer version
2: inserted; file not in repo; added there in .txt.gz format if
   the file was marked as complete in the DB; otherwise in uncompressed .txt format.

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
x = syncDBtoRepo(SERNO, RECVDIR, REPODIR, BKUPDIR)
write.csv(x, stdout(), row.names=FALSE)
