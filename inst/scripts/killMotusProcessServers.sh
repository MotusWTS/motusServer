#!/bin/bash
#
# kill the specified motus process server(s) if they are running,
# or kill all motus process servers if none is specified

if [[ "$*" == "" ]]; then
    cat <<EOF
Usage:  killMotusProcessServers.sh [-a] [-g] [ID] [ID] ...
Kill motusProcessServer processes.  Specify the processes
to kill by one or more integer ID numbers, or specify "-a"
to kill all of them.

EOF
    exit 1;
fi

PNUMS=""
MAXPNUM=8

if [[ "$1" == "-a" ]]; then
    shift
    for i in `seq 1 $MAXPNUM`; do
        if [[ -f /sgm/processServer$i.pid ]]; then
            PNUMS="$PNUMS $i"
        fi
    done
fi
GRACEFUL=""

if [[ "$1" == "-g" ]]; then
    GRACEFUL="y"
    shift
fi

for i in $PNUMS; do
    KILLFILE=/sgm/queue/0/kill$i
    if [[ $GRACEFUL ]]; then
        touch $KILLFILE
    else
        PID=`cat /sgm/processServer$i.pid`
        if [[ "$PID" != "" ]]; then
            pkill -g $PID
            echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Process server for queue $i killed. >> /sgm/logs/mainlog.txt
            rm -f /sgm/processServer$i.pid
        fi
    fi
done
