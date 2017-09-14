#!/bin/bash
#
# kill the motus data server if it is running
#
# specify '-g' to do so gracefully; i.e. send the server
# a shutdown request via http, and give it up to 5 minutes
# to respond.  This prevents any requests from being
# interrupted.

DATA_SERVER_KILL_URL=http://localhost:55930/custom/_shutdown

if [[ "$1" == "-g" ]]; then
    ## send the kill request, waiting up to 5 minutes for a reply,
    ## at which point the server has shut itself down, or is so
    ## busy a graceful shutdown is impossible.
    echo 'sending shutdown request to dataServer and waiting up to 5 minutes'
    GET -t5m $DATA_SERVER_KILL_URL
fi

PIDFILE=/sgm/dataServer.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    rm -f $PIDFILE
    echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Data server killed. >> /sgm/logs/mainlog.txt
fi
