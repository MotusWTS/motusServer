#!/bin/bash
#
# kill the motus data server if it is running
PIDFILE=/sgm/dataServer.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    rm -f $PIDFILE
fi
