#!/bin/bash
#
# kill the specified motus process server(s) if they are running,
# or kill all motus process servers if none is specified

if [[ "$*" == "" ]]; then
    cat <<EOF
Usage:  killMotusProcessServers.sh [-a] [ID] [ID] ...
Kill motusProcessServer processes.  Specify the processes
to kill by one or more integer ID numbers, or specify "-a"
to kill all of them.

EOF
    exit 1;
elif [[ "$*" == "-a" ]]; then
    PIDFILES=`ls -1 /sgm/processServer*.pid`
else
    PIDFILES=""
    for i in $*; do
        PIDFILES="$PIDFILES `ls -1 /sgm/processServer$i.pid`"
    done
fi

for f in $PIDFILES; do
    PID=`cat $f`
    if [[ "$PID" != "" ]]; then
        pkill -g $PID
        rm -f $f
    fi
done
