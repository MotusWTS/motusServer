#!/bin/bash
umask 0002

## Emails are saved uncompressed into the queue directory /sgm/incoming
## A server() function from the motus package handles further processing
## when it detects a file has been written there.
## Emails are recognized by their filename format:
##
##   msg_YYYY-MM-DDTHH-MM-SS.SSSSSS.txt
##

DATE=`date -u +%Y-%m-%dT%H-%M-%S.%6N`
DEST=/sgm/incoming/msg_$DATE.txt
LOGFILE=/sgm/logs/emails.log.txt

echo Got message $DATE >> $LOGFILE

## Save it to a file, dropping CR
/bin/cat | tr -d '\r' > $DEST
