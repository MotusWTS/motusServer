#!/usr/bin/Rscript

._(` (

   getWeTransferFile.R

Download a file from wetransfer.com, given a URL obtained
from an email.  The file is placed in /sgm/downloads/wetransfer-XXXXXX

Call this script as so:

  getWeTransferFile.R URL

._(` )

ARGS = commandArgs(TRUE)

if (length(ARGS) != 1) {
  ._SHOW_INFO()
  quit(save="no")
}

suppressWarnings(suppressMessages(require(motus)))
EMAILURL = ARGS[1]

cat("Grabbing: ", EMAILURL, "\n")

if (grepl("^https://we\\.tl/", EMAILURL, perl=TRUE)) {
    msg = downloadWetransferConf(EMAILURL, MOTUS_PATH$DOWNLOADS)
} else if (grepl("^https://(?:www\\.)?wetransfer\\.com/downloads/", EMAILURL, perl=TRUE)) {
    msg = downloadWetransferDirect(EMAILURL, MOTUS_PATH$DOWNLOADS)
} else {
    stop("Unrecognized URL format.")
}

hashName = attr(msg, "hashName")
fileName = attr(msg, "fileName")
## cat("Got ", hashName, " and ", fileName, "\n")
dir.create(paste0("/sgm/downloads/", hashName), showWarnings=FALSE)
invisible(file.rename(fileName, file.path("/sgm/downloads", hashName, basename(fileName))))
cat(format(Sys.time()), " ", EMAILURL, "\n", file=file("/sgm/logs/wetransferlog.txt", "a"))
cat(msg)
cat(paste0(" to /sgm/downloads/", hashName, "/", basename(fileName), "\n"))
