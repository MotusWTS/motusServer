#!/bin/bash
#
# kill the motus email server if it is running
PIDFILE=/sgm/emailServer.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    rm -f $PIDFILE
fi
