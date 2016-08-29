#!/bin/bash
umask 0002

## Emails are saved uncompressed into the queue directory /sgm/incoming
## a server() function from the motus package handles further processing
## when it detects a file has been written there.
## Emails are recognized by their filename format:
##
##   msg_YYYY-MM-DDTHH-MM-SS.SSSSSSSSS
##

DATE=`date -u +%Y-%m-%dT%H-%M-%S.%N`
DEST=/sgm/incoming/msg_$DATE
LOGFILE=/sgm/logs/emails.log.txt

echo Got message $DATE >> $LOGFILE

## Save it to a file.
/bin/cat > $DEST
