#!/usr/bin/Rscript
#'
#' clear the contents of all transfer tables in both the mysql 'motus' database
#' and in individual receiver databases (the 'motusTX' table)
#'

cat("\n\n\n *********** W A R N I N G ***********\n \n \n")
cat("This will delete all data from transfer tables in the MySQL motus database,\n")
cat("\n\n  and\n\ndelete all data from the motusTX tables in *all* receiver sqlite databases.\n\n")
cat("If you are sure you want to do this, enter 'yes' and hit Enter\n")
cat("Any other input, or interrupting, will abort this process.\n")

if (!identical(readLines("stdin", n=1), "yes"))
    stop("aborted clearTransferTables")

library(motusServer)
Server = safeSQL(openMotusDB())

cat("Emptying all transfer tables in the MySQL motus database\n")
## turn off foreign key checking to avoid issues with linked tables

Server(" SET FOREIGN_KEY_CHECKS = 0;")
Server(" TRUNCATE TABLE hits;       ")
Server(" TRUNCATE TABLE gps;        ")
Server(" TRUNCATE TABLE batches;    ")
Server(" TRUNCATE TABLE runs;       ")
Server(" TRUNCATE TABLE batchProgs; ")
Server(" TRUNCATE TABLE batchParams;")
Server(" TRUNCATE TABLE tagAmbig;   ")
Server(" TRUNCATE TABLE batchDelete;")
Server(" TRUNCATE TABLE runUpdates; ")
Server(" TRUNCATE TABLE pulseCounts;")
Server(" SET FOREIGN_KEY_CHECKS = 1;")

allSerno = sub(".motus", "", dir(MOTUS_PATH$RECV, pattern=(".*\\.motus$")))

for (serno in allSerno) {
    sql = safeSQL(getRecvSrc(serno))
    cat("Emptying motusTX table for receiver", serno, "\n")
    sql("delete from motusTX")
    sql("update tagAmbig set masterAmbigID=null")
    sql(.CLOSE=TRUE)
}
