#!/bin/bash

# daily backup of sqlite3 files; each table in each db is backed up in chunks, to avoid
# holding read locks for too long.  Only rowid tables are backed up.

# we maintain up to a month's worth of backups for each .sqlite3 database in SRCDIR

SRCDIR=/sgm_hd
SQLITEDBS=`cd $SRCDIR; ls -1 *.sqlite`
DATE=`date -Is`
DOM=`date +%d`
TARGETDIR=/home/sg/db_backups/sqlite/$DOM
LOGFILE=/sgm/logs/backups.txt

rm -rf $TARGETDIR/*
mkdir $TARGETDIR

echo "$DATE: Backing up sqlite files from $SRCDIR to $TARGETDIR" >> $LOGFILE
for db in $SQLITEDBS ; do
    echo $db >> $LOGFILE
    /sgm_hd/bin/backup_sqlite_db.sh $SRCDIR/$db $TARGETDIR/$db >> $LOGFILE 2>&1
done
