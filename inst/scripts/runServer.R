#!/usr/bin/Rscript

library(motus)
LOG = file("/sgm/logs/mainlog.txt", "a")
repeat {
    tryCatch(
        server(),
        error = function(e) {
            cat(capture.output(e), "\n", file=LOG)
            cat(capture.output(traceback()), "\n", file=LOG)
        }
    )
}
