#!/bin/bash
#
# kill the motus status server (API version) if it is running
#
# specify '-g' to do so gracefully; i.e. send the server
# a shutdown request via http, and give it up to 5 minutes
# to respond.  This prevents any requests from being
# interrupted.

STATUS_SERVER_KILL_URL=http://localhost:22439/custom/_shutdown

if [[ "$1" == "-g" ]]; then
    ## send the kill request, waiting up to 5 minutes for a reply,
    ## at which point the server has shut itself down, or is so
    ## busy a graceful shutdown is impossible.
    echo 'sending shutdown request to statusServer (API version) and waiting up to 1 minute'
    GET -t1m $STATUS_SERVER_KILL_URL
fi

PIDFILE=/sgm/statusServer2.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    echo `date +%Y-%m-%dT%H-%M-%S.%6N`: "Status server (API version) killed." >> /sgm/logs/mainlog.txt
    rm -f $PIDFILE
fi
