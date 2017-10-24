#!/bin/bash

# daily backup of git repos etc. in /home/sg/src/ to /mnt/sgdata/db_backups/src/
# up to 1 week of backups maintained

SRCDIR=/home/sg/src
DOW=`date +%u`
TARGETDIR=/home/sg/db_backups/src/$DOW
LOGFILE=/sgm/logs/backups.txt
DATE=`date -Is`

rm -rf $TARGETDIR/*
mkdir $TARGETDIR

echo "$DATE: Backing up src repos from $SRCDIR to $TARGETDIR" >> $LOGFILE
rsync -a $SRCDIR/ $TARGETDIR/  >> $LOGFILE 2>&1
