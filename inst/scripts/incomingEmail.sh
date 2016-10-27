#!/bin/bash
umask 0007

## Each email is saved in a newly-created directory with a timestamp name.
## The email is saved uncompressed but with CR (ascii 0x0d) deleted into
## a file called "msg" in that directory.
## The new directory is moved to:
##
##   - /sgm/embargoed_inbox if the file /sgm/EMBARGO exists
##   - /sgm/inbox           otherwise
##
## An emailServer() function from the motus package handles further processing
## when it detects a folder has been moved to /sgm/inbox
##

if [[ -f /sgm/EMBARGO ]]; then
    INCOMING=/sgm/inbox_embargoed
else
    INCOMING=/sgm/inbox
fi

## bash printf %()T formats don't support fractional seconds, so use date
DATE=`date -u +%Y-%m-%dT%H-%M-%S.%9N`

DEST=$INCOMING/$DATE

LOGFILE=/sgm/logs/emails.log.txt

echo Received $DATE >> $LOGFILE

## Save it to a file, dropping CR
/bin/cat | tr -d '\r' > $DEST
