#!/bin/bash
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
SYNCFILE=/sgm/remote/sync/$SERNO
JOBFILE=/sgm/remote/atjobs/$SERNO

# remove any existing at job for this receiver; we don't want sporadic
# disconnect / reconnect by the receiver to launch multiple
# interleaved sequences of syncReceiver jobs

if [[ -f $JOBFILE ]]; then
    atrm `cat $JOBFILE`
    rm -f $JOBFILE
fi

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
        rm -f $SYNCFILE
        touch $SYNCFILE
    fi

    ## launch the at-job, and record its at-job number under the receiver serial number
    ## (this number can be used to kill the at-job with atrm; see above)
    echo $0 $SERNO $WAITLO $WAITHI | at -M now + $WAIT minutes 2>&1 | gawk '/^job/{print $2}' > $JOBFILE
fi
