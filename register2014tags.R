#!/usr/bin/Rscript

library(dplyr)

tags = as.tbl(read.csv("/SG/2014_tags.csv", as.is=TRUE))
tags = tags %>% arrange(proj, id)

log = "/home/john/proj/motus/2014_tag_reg_transfer_log.txt"
cat("Log of 2014 tag registration\n", file=log)

for (i in 1:nrow(tags)) {
    cmd = sprintf("/SG/code/motusRegisterTag.R 2014 %s %d >> %s 2>&1", tags$proj[i], tags$id[i], log)
    cat("Doing: ", cmd, "\n")
    system(cmd)
}

