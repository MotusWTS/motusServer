#!/usr/bin/Rscript
#
._(` (
  lastError.R [-f] [N]

Dump the stack trace from a recent motus server error.

Defaults to N=1, which means most recent; 2 means 2nd most recent,
and so on.

If -f is specified, dump the values of variables in the frame.
Otherwise, just show the call stack.

._(` )

FULL = FALSE
N = 1

ARGS = commandArgs(TRUE)
while (length(ARGS) > 0) {
    if (ARGS[1] == "-f") {
        FULL = TRUE
    } else {
        N = as.integer(ARGS[1])
    }
    ARGS = ARGS[-1]
}

suppressWarnings(suppressMessages(library(motus)))

errors = dir(motus:::MOTUS_PATH$ERRORS, full.names=TRUE)

M = length(errors)

if (N > M)
    stop("N is too large, there are only ", M, " saved stack dumps")

file = errors[M - N + 1]

cat("Stack dump from file: ", basename(file), "\n")
dump = suppressMessages(suppressWarnings(readRDS(file)))

if (FULL) {
    for (i in seq(along=dump)) {
        print(names(dump)[i])
        print(as.list(dump[[i]]))
    }
} else {
    print(dump)
}
