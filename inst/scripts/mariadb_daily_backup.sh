#!/bin/bash
#
# make a backup of mariadb to /home/sg/db_backups/mysql/xtrabackup/
#
# If it's the first day of the month, or there's no 'full' subdirectory,
# make a full backup to the 'full' subdirectory
# in these steps:
#    delete folders 'prev_full' and 'prev_inc_*'
#    move 'full' to 'prev_full', and 'inc_*' to 'prev_inc_*'
#    make full backup to 'full' folder
# Otherwise,
#    make incremental backup based on 'inc_N-1' (if it exists) or 'full' folder to 'inc_N'
#    where N is day of the month; N >= 2
#
# This way, we always have at least one month's worth of full + daily incremental
# backups, once the backup system has been running for at least 1 month.

# The backup target directory.  This should be on NAS, **not on the local hard drive**

TARGETDIR=/home/sg/db_backups/mysql/
LOGFILE=/sgm/logs/backups.txt
DATE=`date -Is`
DOM=`date +%d`
FULL_TARGET=$TARGETDIR/full
INC_TARGET=$TARGETDIR/inc_$DOM
PREV_INC_TARGET=$TARGETDIR/$(($DOM - 1))

if [[ $DOM == 1 || ! -d $FULL_TARGET ]]; then
   ## full backup on 1st day of month
   rm -rf $TARGETDIR/prev_*
   mv $TARGETDIR/full $TARGETDIR/prev_full
   for f in $TARGETDIR/inc_*; do
      mv $f ${f/inc_/prev_inc_}
   done
   echo "$DATE: Backing up mariadb files (full) to $TARGETDIR" >> $LOGFILE
   mariabackup --defaults-extra-file=/home/sg/.secrets/mariadb_root_password -u root --backup --target-dir=$FULL_TARGET >> $LOGFILE 2>&1
else
   if [[ -f $PREV_INC_TARGET ]]; then
      BASEDIR=$PREV_INC_TARGET
   else
      BASEDIR=$FULL_TARGET
   fi
   echo "$DATE: Backing up mariadb files (incremental) to $TARGETDIR" >> $LOGFILE
   mariabackup --defaults-extra-file=/home/sg/.secrets/mariadb_root_password -u root --backup --incremental-basedir=$BASEDIR --target-dir=$INC_TARGET >> $LOGFILE 2>&1
fi
