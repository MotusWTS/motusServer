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
# we create the empty /sgm/remote/sync/SERNO using touch, generate a random
# wait time between WAITLO and WAITHI minutes, then launch an at-job
# for this script.
#
# If WAITLO or WAITHI are not specified, then defaults are used, and
# the delay occurs *before* the sync job is launched for the first
# time.

## sanitize SERNO by removing everything but alphanumerics and '-'
SERNO=${1/[^-[:alnum:]]/}
## sanitize WAITLO, WAITHI by removing non-digits
WAITLO=${2/[^0-9]/}
WAITHI=${3/[^0-9]/}

RUNNOW=1
REMOTE=/sgm/remote
RECEIVERDB=/sgm/remote/receivers.sqlite
SYNCFILE=$REMOTE/sync/$SERNO
JOBFILE=$REMOTE/atjobs/$SERNO
BARE_SERNO=${SERNO/SG-/}
CONNECTION=$REMOTE/connections/$BARE_SERNO

### <fix_issue_126>
### temporary measure: fix tunnel port collisions
### see: https://github.com/jbrzusto/motusServer/issues/126

# array of bad ports by serial number of the SG we need to change it for

declare -A BADPORT
BADPORT[A4BCRPI27DE6]=40587
BADPORT[392CRPI2EB35]=40588
BADPORT[9E62RPI2EDEF]=40589
BADPORT[4815BBBK1A47]=40590
BADPORT[1315BBBK0136]=40591
BADPORT[1914BBBK0929]=40592
BADPORT[1315BBBK0083]=40594
BADPORT[1215BBBK1031]=40595
BADPORT[1315BBBK0112]=40596
BADPORT[1215BBBK1749]=40597
BADPORT[1215BBBK1778]=40598
BADPORT[1315BBBK0110]=40599
BADPORT[1215BBBK1796]=40600

if [[ ${BADPORT[$BARE_SERNO]} ]]; then
    # see whether the tunnel port is the old, colliding one; i.e. <= 40600
    PORT=`sqlite3 $RECEIVERDB "pragma busy_timeout=30000; select tunnelport from receivers where serno='$BARE_SERNO'"`
    if [[ ! "$PORT" ]]; then
        # this is a receiver which needs a new tunnel port
        # the easiest way to achieve this is to remove existing credentials
        # for it on both the SG and server side, then cause it to reboot
        sshpass -p root ssh -oStrictHostKeyChecking=no -p ${BADPORT[$BARE_SERNO]} root@localhost "cd /home/bone/.ssh; rm -f tunnel_port id_dsa id_dsa_pub; sleep 20; reboot"
        /sgm/bin/remove_receiver.sh -y $BARE_SERNO
        exit 4
    fi
fi

### </fix_issue_126>

# remove any existing at job for this receiver; we don't want sporadic
# disconnect / reconnect by the receiver to launch multiple
# interleaved sequences of syncReceiver jobs

if [[ -f $JOBFILE ]]; then
    atrm `cat $JOBFILE`
    rm -f $JOBFILE
fi

if [[ -f $CONNECTION ]]; then
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
