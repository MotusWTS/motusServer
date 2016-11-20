#!/bin/bash
#
# kill the motus status server if it is running
PIDFILE=/sgm/statusServer.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    rm -f $PIDFILE
fi
