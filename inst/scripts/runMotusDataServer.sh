#!/bin/bash
#
# run the motus data server
#

# assume no tracing

TRACE=0
PORT=55930 ## = 0xda7a

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

Usage: runMotusDataServer.sh [-h] [-t] [-p PORT]

Run the motus data server which answers requests for detection data.

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

PIDFILE=/sgm/dataServer.pid
if [[ -s $PIDFILE ]]; then
    OLDPID=`cat $PIDFILE`
    if [[ -d /proc/$OLDPID ]]; then
        cat <<EOF

There is already a motus data server running, so I won't start
another.  In the current design, the data server is a singleton.

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
    echo `date +%Y-%m-%dT%H-%M-%S.%6N`: Data server killed. >> /sgm/logs/mainlog.txt
    rm -f $PIDFILE
    if [[ $TRACE != 0 && "$MYTMPDIR" =~ /tmp/tmp* ]]; then
        rm -rf "$MYTMPDIR"
    fi

    ## delete locks held by this process
    sqlite3 /sgm/server.sqlite "pragma busy_timeout=10000; delete from symLocks where owner=$SPID" > /dev/null
}

## call the cleanup handler on exit

trap onExit EXIT

echo $$ > $PIDFILE

if [[ $TRACE == 0 ]]; then
    while (( 1 )); do
        nohup Rscript -e "library(motusServer);dataServer(port=$PORT, tracing=FALSE)" >> /sgm/logs/data.txt 2>&1
        sleep 15
    done
else
    MYTMPDIR=`mktemp -d`
    cd $MYTMPDIR
    ## set up an .Rprofile; because loading of the usual libraries
    ## happens after .Rprofile is eval'd, they won't have been loaded
    ## when processServer is called, so load them manually
    cat <<EOF > .Rprofile
    for (l in c("datasets", "utils", "stats", "motusServer"))
        library(l, character.only=TRUE)
    rm(l)
    options(error=recover)
    dataServer(port=$PORT, tracing=TRUE)
EOF
    R
fi
