#!/bin/bash
umask 0002

DATE=`date -u +%Y-%m-%dT%H-%M-%S.%N`
DEST=/home/sg/messages/msg_$DATE
LOGFILE=/home/sg/log.txt

echo Got message $DATE >> $LOGFILE

## Save it to a file.
/bin/cat > $DEST

## run the processing code on it
OUTFILE=$(tempfile)

/home/sg/bin/processMessage.py $DEST > $OUTFILE 2>&1
cat $OUTFILE >> $LOGFILE

SUBJECT=$(grep -m 1 ^Subject: $DEST)
cat $OUTFILE | mail -s "$SUBJECT" jbrzusto@fastmail.fm
rm -f $OUTFILE

## archive it
lzip $DEST
