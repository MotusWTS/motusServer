#!/bin/bash
#
# kill the motus data server if it is running
#
# specify '-g' to do so gracefully; i.e. send the server
# a shutdown request via http, and give it up to 5 minutes
# to respond.  This prevents any requests from being
# interrupted.

GRACEFUL=""
PORT=55930 ## = 0xda7a

while [[ "$1" != "" ]]; do
    case "$1" in
        -g)
            GRACEFUL=1
            ;;

        -p)
            PORT=$2
            if [[ "$PORT" == "" ]]; then
                echo Error: port must be numeric
                exit 1;
            fi
            shift
            ;;

        -h|*)
            cat <<EOF

Usage: killMotusDataServer.sh [-h] [-g] [-p PORT]

Kill the motus data server which answers requests for detection data.

   -h  show usage

   -g  graceful: inform server of kill then wait for up to 5 minutes
       for current job to complete before killing process

   -p PORT kill server listening on local port PORT; default: 59059

EOF
            exit 1;
            ;;
        esac
    shift
done

DATA_SERVER_KILL_URL=http://localhost:$PORT/custom/_shutdown

KILLFILE=/sgm_local/kill.dataServer.$PORT
touch $KILLFILE

if [[ "$GRACEFUL" != "" ]]; then
    ## send the kill request, waiting up to 5 minutes for a reply,
    ## at which point the server has shut itself down, or is so
    ## busy a graceful shutdown is impossible.
    echo 'sending shutdown request to dataServer and waiting up to 5 minutes'
    GET -t5m -d $DATA_SERVER_KILL_URL
fi

PIDFILE=/sgm/dataServer-$PORT.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    rm -f $PIDFILE
    echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Data server on port $PORT killed. >> /sgm/logs/mainlog.txt
fi
