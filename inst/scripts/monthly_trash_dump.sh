#!/bin/bash

# monthly deletion of trash older than 31 days

TRASHDIR=/sgm/trash
DATE=`date -Is`
LOGFILE=/sgm/logs/trash.txt

echo "$DATE: Deleting folders older than 31 days from $TRASHDIR" >> $LOGFILE
find $TRASHDIR -maxdepth 1 -type d -mtime +31 -exec rm -rf '{}' ';'
