#!/bin/bash
#
# kill the specified motus process server(s) if they are running,
# or kill all motus process servers if none is specified

if [[ "$*" == "" ]]; then
    cat <<EOF
Usage:  killMotusProcessServers.sh [-a] [-g] [ID] [ID] ...
Kill motusProcessServer processes.  Specify the processes
to kill by one or more integer ID numbers, or specify "-a"
to kill all of them.  ID are the queue numbers: 1, 2, 3, ...
and 101, 102.

Specify -g (for "graceful") to let each server finish any current
subjob before quitting, so that jobs will be resumed without loss of
data when the servers are subsequently restarted.

EOF
    exit 1;
fi

PNUMS=""

if [[ "$1" == "-a" ]]; then
    shift
    PNUMS=`cd /sgm; ls -1 processServer*.pid | sed -e 's/processServer//; s/.pid//'`
fi


GRACEFUL=""

if [[ "$1" == "-g" ]]; then
    GRACEFUL="y"
    shift
fi

PNUMS="$PNUMS $*"
if [[ "$PNUMS" == "" ]]; then
    exit 0;
fi


for i in $PNUMS; do
    if [[ $i -lt 100 ]]; then
        KILLFILE=/sgm/queue/0/kill$i
    else
        KILLFILE=/sgm/priority/kill$i
    fi
    touch $KILLFILE
    if [[ ! $GRACEFUL ]]; then
        PID=`cat /sgm/processServer$i.pid`
        if [[ "$PID" != "" ]]; then
            pkill -g $PID
            echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Process server for queue $i killed. >> /sgm/logs/mainlog.txt
            rm -f /sgm/processServer$i.pid
        fi
    fi
done
