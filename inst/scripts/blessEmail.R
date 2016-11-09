#!/usr/bin/Rscript

._(` (
   blessEmail.R MSG

Add an authorization toekn to an email message and resubmit it to
the motus processing queue.

MSG is the full path to a stored email message, typically in /sgm/manual
or /sgm/spam

._(` )

ARGS = commandArgs(TRUE)

suppressMessages(suppressWarnings(library(motus)))

MSG       = ARGS[1]

if (is.na(MSG) || ! file.exists(MSG) || file.info(MSG)$isdir) {
    stop("You must specify the full path to a single email message; e.g. in /sgm/spam/2016-09-07T20-52-30.535589_msg.bz2")
}

## decompress if necessary
if (grepl("\\.bz2$", MSG, perl=TRUE)) {
    system2("bunzip2", MSG)
    MSG = sub("\\.bz2$", "", MSG, perl=TRUE)
}

## add a token to the message's subject line
x = readLines(MSG)

## get line with subject, creating new one if none found
subj = grep("^Subject: ", x, perl=TRUE)[1]
if (is.na(subj)) {
    subj = 1
    x = c("Subject: ", x)
}

tok = getUploadToken()

x[subj] = paste(x[subj], tok$token)

writeLines(x, MSG)

toInbox(MSG)
