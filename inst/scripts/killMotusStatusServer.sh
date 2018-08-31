#!/bin/bash
#
# kill the motus status server if it is running
#
# specify '-g' to do so gracefully; i.e. send the server
# a shutdown request via http, and give it up to 5 minutes
# to respond.  This prevents any requests from being
# interrupted.

PORT=59059

while [[ "$1" != "" ]]; do
    case "$1" in
        -p)
            PORT=$2
            if [[ "$PORT" == "" ]]; then
                echo Error: port must be numeric
                exit 1;
            fi
            shift
            ;;
    esac
    shift
done

STATUS_SERVER_KILL_URL=http://localhost:$PORT/custom/_shutdown

KILLFILE=/sgm_local/kill.statusServer.$PORT
touch $KILLFILE

if [[ "$1" == "-g" ]]; then
    ## send the kill request, waiting up to 5 minutes for a reply,
    ## at which point the server has shut itself down, or is so
    ## busy a graceful shutdown is impossible.
    echo 'sending shutdown request to statusServer and waiting up to 1 minute'
    GET -t1m -d $STATUS_SERVER_KILL_URL
fi

PIDFILE=/sgm/statusServer.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Status server on port $PORT killed. >> /sgm/logs/mainlog.txt
    rm -f $PIDFILE
fi
