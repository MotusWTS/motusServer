#!/usr/bin/Rscript
##
## update the tagDepProjectID field in each row of batchRuns
##
## This script included only for the record.  DO NOT RUN.
##
## Going forward, batchRuns.tagDepProjectID will be populated as
## records are added to the batchRuns table.

library(motusServer)
openMotusDB()
options(error=recover)
MotusDB("set @@autocommit=0")
for (b in 1:102744) {
    MotusDB("lock tables batchRuns write, runs write")
    MotusDB("update batchRuns join runs on batchRuns.runID=runs.runID set batchRuns.tagDepProjectID=runs.tagDepProjectID where batchRuns.batchID=%d",b)
    MotusDB("unlock tables")
    cat(b,"\n")
}
MotusDB("create index batchRuns_tagDepProjectID_batchID_runID on batchRuns (tagDepProjectID, batchID, runID)")
