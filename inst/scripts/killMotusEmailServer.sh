#!/bin/bash
#
# kill the motus email server if it is running
# Specify "-g" ("graceful") to let it finish its current subjob first.

KILLFILE=/sgm/killE
GRACEFUL=""
if [[ "$1" == "-g" ]]; then
    GRACEFUL=1
    shift
fi

PIDFILE=/sgm/emailServer.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    if [[ $GRACEFUL ]]; then
        touch /sgm/killE
    else
        pkill -g $PID
    fi
    rm -f $PIDFILE
fi
