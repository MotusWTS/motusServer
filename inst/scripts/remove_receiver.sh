#!/bin/bash
#
# remove_receiver.sh: remove a receiver's registration and any uploaded
# data.
# [-f] : force
# $1: serial number
#

if [[ "$1" == "-f" ]]; then 
    FORCE=1
    shift
fi

SERNO="$1"
if [[ "$SERNO" == "" ]]; then
    echo <<EOF
Usage: remove_receiver.sh SERNO
Removes record of receiver from receiver database, .ssh/authorized_keys etc.
Any uploaded data are deleted!

Actually, all of these are simply saved into different locations.
Old data are moved to ~sg_remote/deleted_streams
and old database entries are moved to the deleted_receivers table.

EOF
    exit 1
fi

echo This will remove all traces, including registration and uploaded
echo data, of receiver with serial number $SERNO
echo
echo Actually, all of these are simply saved into different locations.
echo Old data are moved to ~sg_remote/deleted_streams
echo and old database entries are moved to the deleted_receivers table.
echo
echo -n 'Are you sure ? (y/N) '

read RESP

RESP=${RESP:0:1}

if [[ "$RESP" != "y" && "$RESP" != "Y" ]]; then
    exit 3
fi

if [[ ! -f "/home/sg_remote/.ssh/id_dsa_sg_$SERNO" && ! "$FORCE" ]]; then
    echo Unknown receiver serial number
    exit 2
fi

echo removing pub key from authorized_keys
DATE=`date +%s`

## save old authorized keys line
(
    echo -n "$DATE:";
    grep "/SG_SERNO=$SERNO/d" /home/sg_remote/.ssh/authorized_keys
) >> /home/sg_remote/.ssh/deleted_authorized_keys

sed -i -e "/SG_SERNO=$SERNO/d" /home/sg_remote/.ssh/authorized_keys

echo removing pub/priv keypair
DEST=/home/sg_remote/.ssh/deleted

mv /home/sg_remote/.ssh/id_dsa_sg_$SERNO $DEST/${DATE}:id_dsa_sg_$SERNO
mv /home/sg_remote/.ssh/id_dsa_sg_$SERNO.pub $DEST/${DATE}:id_dsa_sg_$SERNO.pub

echo deleting uploaded data

cd /home/sg_remote/streams

for f in $SERNO.sqlite*; do
    mv $f deleted/${DATE}:$f
done

echo deleting record from receivers database...

echo "insert into deleted_receivers select $DATE,* from receivers where serno=='$SERNO';delete from receivers where serno=='$SERNO';" | sqlite3 /home/sg_remote/receivers.sqlite

echo deleting connection indicator

rm -f /home/sg_remote/connections/$SERNO

echo Done.
