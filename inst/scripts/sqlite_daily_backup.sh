#!/bin/bash

# daily backup of sqlite3 files; each table in each db is backed up in chunks, to avoid
# holding read locks for too long.  Only rowid tables are backed up.

# we maintain up to a month's worth of backups for each .sqlite3 database in SRCDIR

# backups are stored by day-of-month

# we don't backup the motus_meta_db.sqlite since that is created daily by
# another cron job (refreshMotusMetaDB.R)

SRCDIR=/sgm_local
SQLITEDBS=`cd $SRCDIR; ls -1 *.sqlite | grep -v motus_meta_db.sqlite`
DATE=`date -Is`
DOM=`date +%d`
TARGETDIR=/sgm/db_backups/$DOM
LOGFILE=/sgm/logs/backups.txt

rm -rf $TARGETDIR/*
mkdir $TARGETDIR > /dev/null 2>&1

echo "$DATE: Backing up sqlite files from $SRCDIR to $TARGETDIR" >> $LOGFILE
for db in $SQLITEDBS ; do
    echo $db >> $LOGFILE
    /sgm_local/bin/backup_sqlite_db.sh $SRCDIR/$db $TARGETDIR/$db >> $LOGFILE 2>&1
done
