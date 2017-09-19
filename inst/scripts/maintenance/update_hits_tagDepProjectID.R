#!/usr/bin/Rscript
##
## update the tagDepProjectID field in each row of hits.
##
## This script included only for the record.  DO NOT RUN.
##
## Going forward, hits.tagDepProjectID will be populated as
## records are added to the hits table.

library(motusServer)
openMotusDB();
options(error=recover)
MotusDB("set @@autocommit=0")
for (b in 1:102744) {
    MotusDB("lock tables hits write, runs write")
    MotusDB("update runs join hits on runs.runID=hits.runID set hits.tagDepProjectID=runs.tagDepProjectID where batchID=%d",b)
    MotusDB("unlock tables")
    cat(b,"\n");
}
