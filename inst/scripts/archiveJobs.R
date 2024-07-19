#!/usr/bin/Rscript

# Move old jobs into an archival database.
# Improves response times on queries about recent jobs.
# This script was created after the job log grew to 3GB and query response times increased to >20 seconds.

# The intent is for this script to be run on a regular schedule, e.g. daily or weekly.

suppressMessages(suppressWarnings(library(motusServer))) # cron sends an email every time if this isn't made invisible
invisible({
 on.exit(lockSymbol("jobsDB", lock=FALSE))
 ServerDB <<- safeSQL(MOTUS_PATH$SERVER_DB) # The main jobs database
 ArchiveDB <<- safeSQL(MOTUS_PATH$JOB_ARCHIVE_DB)

 # Jobs spawn sub-jobs, which in turn spawn their own sub-jobs, forming a tree of jobs for every root job.
 # We want to archive whole trees which haven't been touched for a given amount of time.
 # Each job has an ID (id), a parent ID (pid), and a root parent ID (stump). Stumps serve as unique IDs for trees.
 # Each job has ctime (creation time) and mtime (modification time).

 # Archive all jobs which are more than one year old.
 oldJobStumps <- ServerDB("select stump from jobs group by stump having max(mtime) < strftime('%s', 'now') - 60*60*24*366")
 oldJobStumps <- paste0(oldJobStumps[,1], collapse=',')
 oldJobs <- ServerDB(paste0("select * from jobs where stump in (", oldJobStumps, ")"))
 # Occasionally jobs will be copied back to the main database, so do this to ensure the write doesn't fail
 ArchiveDB(paste0("delete from jobs where stump in (", oldJobStumps, ")"))
 dbWriteTable(ArchiveDB$con, "jobs", oldJobs, append=TRUE)
 lockSymbol("jobsDB")
 ServerDB(paste0("delete from jobs where stump in (", oldJobStumps, ")"))
 lockSymbol("jobsDB", lock=FALSE)

 # Archive automated upload jobs which are more than one month old.
 # syncReceiver jobs are hourly uploads from older internet-connected SensorGnome receivers.
 # uploadFile jobs from user 347 for project 0 are daily uploads from CTT receivers.
 # uploadFile jobs from users 30751, 27319, 547, or 2512 with filenames with a hexidecimal suffix are hourly uploads from newer SensorGnome receivers.
 oldJobStumps <- ServerDB("select stump from jobs group by stump having max(mtime) < strftime('%s', 'now') - 60*60*24*31")
 oldJobStumps <- paste0(oldJobStumps[,1], collapse=',')
 # Only the root jobs have the types we're searching for.
 oldJobStumps <- ServerDB(paste0("select id from jobs where id in (", oldJobStumps, ") and (type = 'syncReceiver' or motusUserID = 347 and motusProjectID = 0 and type = 'uploadFile' or motusUserID in (547, 2512, 27319, 30751) and json_extract(data, '$.filename') glob '*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9].zip')"))
 oldJobStumps <- paste0(oldJobStumps[,1], collapse=',')
 oldJobs <- ServerDB(paste0("select * from jobs where stump in (", oldJobStumps, ")"))
 # Occasionally jobs will be copied back to the main database, so do this to ensure the write doesn't fail
 ArchiveDB(paste0("delete from jobs where stump in (", oldJobStumps, ")"))
 dbWriteTable(ArchiveDB$con, "jobs", oldJobs, append=TRUE)
 lockSymbol("jobsDB")
 ServerDB(paste0("delete from jobs where stump in (", oldJobStumps, ")"))
})
