#!/bin/bash
#
# checkSyncDBtoRepo.sh
#

if [[ $1 == "" ]]; then
cat <<EOF

checkSyncDBtoRepo.sh:

Check whether syncDBtoRepo.R script results meet some basic sanity checks:

   1. # of files in repo >= # unique (ts, monoBN) pairs in DB

   2. files in bkup dir are smaller than replacement files in repo

call as: checkSyncDBtoRepo.sh SERNO [DBDIR [REPODIR [BKUPDIR]]]


EOF
exit 1;
fi

SERNO=$1
if [[ $2 != "" ]]; then
    DBDIR=$2
else
    DBDIR="/sgm/recv"
fi
if [[ $3 != "" ]]; then
    REPODIR=$3
else
    REPODIR="/sgm/file_repo"
fi
if [[ $4 != "" ]]; then
    BKUPDIR=$4
else
    BKUPDIR="/sgm/trash"
fi

DB=$DBDIR/$SERNO.motus

if [[ ! -f $DB ]]; then
    echo file $DB not found
    exit 2
fi

REPO=$REPODIR/$SERNO

NDB=`sqlite3 $DB "select count(distinct(ts||monoBN)) from files"`
NREPO=`find $REPO -type f | wc -l`

echo -n "File count "
if (( $NREPO >= $NDB )); then echo Okay = $NDB; else echo "FAIL $NREPO < $NDB"; fi

BKUP=$BKUPDIR/$SERNO

find $BKUP -type f | (
    while (( 1 )); do
        read f
        if [[ "$?" != "0" ]]; then
            break
        fi
        a=`ls -al "$f"`
        b=`basename "$f"`
        c=`ls -al $REPO/*/"$b"*`
        echo "$a $c \n";
    done
)
