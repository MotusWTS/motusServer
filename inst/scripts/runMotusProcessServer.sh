#!/bin/bash
#
# run a motus processing server
#

# assume no tracing

TRACE=0
N=0

while [[ "$1" != "" ]]; do
    case "$1" in
        -t)
            TRACE=1
            ;;

        [1-8])
            N=$1
            ;;

        -h|*)
            cat <<EOF

Usage: runMotusProcessServer.sh [-h] [-t] [N]

Run a motus process server that deals with batches of files.

   -h : show usage

   -t enable tracing, so run in foreground.  Program will enter the
      debugger before each job step.

   N [optional] assign this process to queue N.  If not specified,
      uses the first N in 1..8 for which /sgm/processServerN.pid
      does not exist.

EOF
            exit 1;
            ;;
        esac
    shift
done

## grab the first available queue number if none specified

export SPID=$$;

if [[ $N == 0 ]]; then
    ## find an unused queue

    for i in `seq 1 8`; do
        ## We use a lock onn /sgm/locks/queueN to atomically test
        ## existence of and create /sgm/processServerN.pid
        export i=$i
        (
            flock -n 9 || exit 1
            if [[ ! -s /sgm/processServer$i.pid ]]; then
                echo $SPID > /sgm/processServer$i.pid ;
                exit 0;
            fi
            exit 1;
        ) 9>/sgm/locks/queue$i
        rv=$?
        if [[ $rv == 0 ]]; then
            N=$i;
            break
        fi
    done;
else
    PIDFILE=/sgm/processServer$N.pid
    if [[ -s $PIDFILE ]]; then
        OLDPID=`cat $PIDFILE`
        if [[ -d /proc/$OLDPID ]]; then
            cat <<EOF
There is already a server running for queue $N.
Not starting another one.
EOF
            exit 1;
        fi
        echo $SPID > $PIDFILE
    fi
fi

if [[ $N == 0 ]]; then
    cat <<EOF

There are servers running for all available queues (1..8).
Not running another one.

EOF
    exit 1
fi

## restart the process whenever it dies, allowing a
## short interval to prevent thrashing

function onExit {
## cleanup the pid file, and possibly the temporary directory
    rm -f /sgm/processServer$N.pid
    if [[ $TRACE != 0 && "$MYTMPDIR" =~ /tmp/tmp* ]]; then
        rm -rf "$MYTMPDIR"
    fi
}

## call the cleanup handler on exit

trap onExit EXIT

echo $$ > /sgm/processServer$N.pid

if [[ $TRACE == 0 ]]; then
    while (( 1 )); do
  ##      nohup Rscript -e "library(motus);processServer($N, tracing=FALSE)"
        echo running server for queue $N
        ## Kill off the inotifywait process; it's in our process group.
        ## This should happen internally, but might not.
        pkill -g $$ inotifywait
        sleep 15
    done
else
##    MYTMPDIR=`mktemp -d`
##    cd $MYTMPDIR
##    echo "library(motus); options(error=recover); processServer($N, tracing=TRUE)" > .Rprofile
##    R
    echo running tracing server for queue $N
##    pkill -g $$ inotifywait
fi
