#!/bin/bash
#
# run the motus status server
#

# assume no tracing

TRACE=0
PORT=59059

while [[ "$1" != "" ]]; do
    case "$1" in
        -t)
            TRACE=1
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

Usage: runMotusStatusServer.sh [-h] [-t] [-p PORT]

Run the motus status server which replies to requests for job and server status.

   -h  show usage

   -t  enable tracing, so run in foreground.  Program will enter the
       debugger before each job step.

   -p PORT listen on local port PORT; default: 59059

EOF
            exit 1;
            ;;
        esac
    shift
done

export SPID=$$;

PIDFILE=/sgm/statusServer.pid
if [[ -s $PIDFILE ]]; then
    OLDPID=`cat $PIDFILE`
    if [[ -d /proc/$OLDPID ]]; then
        cat <<EOF

There is already a motus status server running, so I won't start
another.  In the current design, the status server is a singleton.

EOF
        exit 1;
    fi
    echo $SPID > $PIDFILE
fi

## restart the process whenever it dies, allowing a
## short interval to prevent thrashing

function onExit {
## cleanup the pid file, and possibly the temporary R file
## Log to the master log, because this server is stopped via signal.
    echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Status server killed. >> /sgm/logs/mainlog.txt
    rm -f $PIDFILE
    if [[ $TRACE != 0 && "$MYTMPDIR" =~ /tmp/tmp* ]]; then
        rm -rf "$MYTMPDIR"
    fi

    ## delete locks held by this process
    sqlite3 /sgm_local/server.sqlite "pragma busy_timeout=10000; delete from symLocks where owner=$SPID" > /dev/null
}

## call the cleanup handler on exit

trap onExit EXIT

echo $$ > $PIDFILE

if [[ $TRACE == 0 ]]; then
    while (( 1 )); do
        nohup Rscript -e "library(motusServer);statusServer(port=$PORT, tracing=FALSE)" >> /sgm/logs/status.txt 2>&1
        sleep 15
    done
else
    MYTMPDIR=`mktemp -d`
    cd $MYTMPDIR
    ## set up an .Rprofile; because loading of the usual libraries
    ## happens after .Rprofile is eval'd, they won't have been loaded
    ## when processServer is called, so load them manually
    cat <<EOF > .Rprofile
    for (l in c("datasets", "utils", "grDevices", "graphics", "stats", "motusServer"))
        library(l, character.only=TRUE)
    rm(l)
    options(error=recover)
    statusServer(port=$PORT, tracing=TRUE)
EOF
    R
fi
