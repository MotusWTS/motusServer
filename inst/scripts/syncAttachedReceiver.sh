# Repeatedly trigger a job to grab and process new files from an attached SG.
#
# This script creates an empty file with a given SG serial number in /sgm/sync
# The motusSyncServer detects this, then queues a job to sync that receiver.
#
# This script also creates an at job for itself, so that sync happens again
#
# Usage:
#     syncAttachedReceiver.sh SERNO WAITLO WAITHI
#
# If the receiver with the serial number SERNO is indeed attached,
# we create the empty /sgm/sync/SERNO using touch, generate a random
# wait time between WAITLO and WAITHI minutes, then launch an at-job
# for this script.
#
# If WAITLO or WAITHI are not specified, then defaults are used, and
# the delay occurs *before* the sync job is launched for the first
# time.

SERNO=$1
WAITLO=$2
WAITHI=$3
RUNNOW=1

if [[ -f ~sg_remote/connections/${SERNO/SG-/} ]]; then
    ## sanitize SERNO by removing everything but alphanumerics and '-'
    SERNO=${SERNO//[^-[:alnum:]]/}

    ## sanitize WAITLO, WAITHI by removing non-digits
    WAITLO=${WAITLO//[^0-9]/}
    WAITHI=${WAITHI//[^0-9]/}

    ## by default, use WAITLO = 30 minutes, WAITHI = 90  (average of 1 hour)
    if [[ "$WAITLO" == "" ]]; then
        WAITLO=30
        RUNNOW=""
    fi
    if [[ "$WAITHI" == "" ]]; then
        WAITHI=90
        RUNNOW=""
    fi

    WAIT=$(( $WAITLO + `/usr/bin/od -N 2 -t u2 -A n /dev/urandom` * ($WAITHI - $WAITLO) / 65535 ))

    if [[ $RUNNOW ]]; then
        ## trigger a sync job by the motusSyncServer
        touch /sgm/sync/$SERNO
    fi

    echo $0 $SERNO $WAITLO $WAITHI | at -M now + $WAIT minutes
fi
