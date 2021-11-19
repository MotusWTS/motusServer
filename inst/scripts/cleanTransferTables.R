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

suppressMessages(suppressWarnings(library(motusServer))) # cron sends an email every time if this isn't made invisible

MotusDB <- openMotusDB()

# Largest batchID from one month ago.
maxBatchId <- MotusDB("select max(batchID) from batches where unix_timestamp() - ts > 60*60*24*31")[,1]

# ...but batches can be out-of-order. This can happen because of parallel processing, and because of error repair which doesn't re-set ts.
# Ensure that we skip out-of-order batches.
buffer <- 60 * 60 * 24 # Ignore batches which are out-of-order by less than 1 day
shouldBeEmpty <- MotusDB(sprintf("select batchID from batches where batchID < %d and ts > (select ts from batches where batchID = %1$d) + %d limit 1", maxBatchId, buffer))
skipList <- c()
while(nrow(shouldBeEmpty) > 0) {
 skipList <- c(skipList, maxBatchId)
 maxBatchId <- MotusDB(sprintf("select max(batchID) from batches where unix_timestamp() - ts > 60*60*24*31 and batchID not in (%s)", paste0(skipList, collapse=",")))[,1]
 shouldBeEmpty <- MotusDB(sprintf("select batchID from batches where batchID < %d and ts > (select ts from batches where batchID = %1$d) + %d limit 1", maxBatchId, buffer))
}

# Deleting 10,000 rows from the largest table (hits) seems to take between 5 and 15 seconds when nothing else is happening, but can take 10 times longer when other processes are actively using the database.
delLimit <- 10000

deleteOldRecords <- function(tableName, batchIdFieldName = "batchID") {
 # Deleting all the rows at once can tie up the database for hours if there are a large number of rows to be deleted.
 # Deleting delLimit rows at a time lets other processes insert rows in between deletions.
 repeat {
  delCount <- MotusDB(sprintf("delete from %s where %s <= %d limit %d", tableName, batchIdFieldName, maxBatchId, delLimit))
  if(delCount < delLimit)
   break
 }
 # Running this after deleting rows frees unused space in both the table and the indices.
 # This improves performance on all operations if the tables are large enough.
 invisible(MotusDB(sprintf("optimize table %s", tableName)))
}

deleteOldRecords("hits")
deleteOldRecords("pulseCounts")
deleteOldRecords("batchRuns")
deleteOldRecords("runs", batchIdFieldName="batchIDbegin")
deleteOldRecords("gps")
