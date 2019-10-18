#!/bin/bash
#
# kill the motus status server (API version) if it is running
#
# specify '-g' to do so gracefully; i.e. send the server
# a shutdown request via http, and give it up to 1 minute
# to respond.  This prevents any requests from being
# interrupted.

PORT=22439 ## 0x57a7
GRACEFUL=""

while [[ "$1" != "" ]]; do
    case "$1" in
        -g)
            GRACEFUL=1;
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

Usage: killMotusStatusServer2.sh [-h] [-g] [-p PORT]

Kill the motus status server (API version) which replies to requests
for job and server status.

   -h  show usage

   -g  graceful: wait up to 1 minute for current request to complete
       before killing server

   -p PORT kill server listening on local port PORT; default: 22439

EOF
            exit 1;
            ;;
        esac
    shift
done

STATUS_SERVER_KILL_URL=http://localhost:$PORT/custom/_shutdown

KILLFILE=/sgm_local/kill.statusServer2.$PORT
touch $KILLFILE

if [[ "$GRACEFUL" != "" ]]; then
    ## send the kill request, waiting up to 1 minute for a reply,
    ## at which point the server has shut itself down, or is so
    ## busy a graceful shutdown is impossible.
    echo 'sending shutdown request to statusServer (API version) and waiting up to 1 minute'
    GET -t1m -d $STATUS_SERVER_KILL_URL
fi

PIDFILE=/sgm/statusServer2-$PORT.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    pkill -g $PID
    echo `date +%Y-%m-%dT%H-%M-%S.%6N`: "Status server (API version) on port $PORT killed." >> /sgm/logs/mainlog.txt
    rm -f $PIDFILE
fi
