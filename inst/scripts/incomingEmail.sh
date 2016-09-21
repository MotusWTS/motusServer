#!/bin/bash
umask 0002

## Emails are saved uncompressed into the incoming directory /sgm/incoming
## if the file /sgm/QUEUE_OPEN exists; otherwise into /sgm/embargoed_incoming
## where no further action is taken.
##
## A server() function from the motus package handles further processing
## when it detects a file has been written to /sgm/incoming
##
## Emails are recognized by their filename format:
##
##   YYYY-MM-DDTHH-MM-SS.SSSSSS_msg
##

DATE=`date -u +%Y-%m-%dT%H-%M-%S.%6N`
DEST=/sgm/tmp/${DATE}_msg
if [[ -f /sgm/EMBARGO ]]; then 
    INCOMING=/sgm/embargoed_incoming
else
    INCOMING=/sgm/incoming
fi

LOGFILE=/sgm/logs/emails.log.txt

echo Got message $DATE >> $LOGFILE

## Save it to a file, dropping CR
/bin/cat | tr -d '\r' > $DEST

## Move it (once complete) to the incoming folder
## We do this in two steps so as not to trigger two separate
## events per email, one on file creation, one on file close.

/bin/mv $DEST $INCOMING
