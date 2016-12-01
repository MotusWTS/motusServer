#!/bin/bash
#
# kill the motus email server if it is running
# Specify "-g" ("graceful") to let it finish its current subjob first.

KILLFILE=/sgm/inbox/killE
GRACEFUL=""
if [[ "$1" == "-g" ]]; then
    GRACEFUL=1
    shift
fi

PIDFILE=/sgm/emailServer.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    if [[ $GRACEFUL ]]; then
        touch $KILLFILE
    else
        pkill -g $PID
        echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Email server killed. >> /sgm/logs/mainlog.txt
    fi
    rm -f $PIDFILE
fi
