#!/usr/bin/Rscript

# Delete old data in the transfer tables.
# Improves transfer times.
# This script was created after 3 years of data had accumulated.
# Deleting that accumulation sped up some operations by a factor of 50, improving overall transfer times by a factor of 3.

# The intent is for this script to be run on a regular schedule, e.g. daily or weekly.
# No matter how often it's run, it only deletes data which is more than one month old.

# Currently data is transferred to the main Motus database every 20 minutes.
# So the transfer process would have to be down for a month without anyone noticing before this script would start deleting data which had not yet been transferred.
# Even then, all data in these tables are copied from the receiver databases, so nothing would be permanently lost.

# This script relies on batchIDs monotonically increasing over time.
# If that ever changes, some indexes will have to be added to these tables to make a correct algorithm performant.

suppressMessages(suppressWarnings(library(motusServer)))

MotusDB <- openMotusDB()

# Largest batchID from one month ago.
maxBatchId = MotusDB("select max(batchID) from batches where unix_timestamp() - ts > 60*60*24*31")

deleteOldRecords <- function(tableName, batchIdFieldName = "batchID") {
 delCount = 1
 while(delCount > 0) {
  delCount = MotusDB(paste0("delete from ", tableName, " where ", batchIdFieldName, " <= ", maxBatchId, " limit 10000"))
  # Sleep for 10 seconds every 10,000 deletions. Allows other processes to continue using the database.
  # Deleting 10,000 rows from the largest table (hits) seems to take between 1 and 10 seconds.
  # Too short? Too long?
  Sys.sleep(10)
 }
}

deleteOldRecords("hits")
deleteOldRecords("pulseCounts")
deleteOldRecords("batchRuns")
deleteOldRecords("runs", batchIdFieldName="batchIDbegin")
deleteOldRecords("gps")
