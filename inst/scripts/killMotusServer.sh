#!/bin/bash
#
# kill any currently running motus server(s)
PIDFILE=/sgm/server.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    rm -f $PIDFILE
fi
