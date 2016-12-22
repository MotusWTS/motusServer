#!/bin/bash
#
# kill the motus upload server if it is running
## NOT WORKING YET:  Specify "-g" ("graceful") to let it finish its current subjob first.

# KILLFILE=/sgm/uploads/kill
# GRACEFUL=""
# if [[ "$1" == "-g" ]]; then
#     GRACEFUL=1
#     shift
# fi

PIDFILE=/sgm/uploadServer.pid
PID=`cat $PIDFILE`
if [[ "$PID" != "" ]]; then
    # if [[ $GRACEFUL ]]; then
    #     touch $KILLFILE
    # else
        pkill -g $PID
        echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Upload server killed. >> /sgm/logs/mainlog.txt
    # fi
    rm -f $PIDFILE
fi
