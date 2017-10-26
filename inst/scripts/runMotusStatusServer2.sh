#!/bin/bash
#
# run the motus status server (API version)
#

# assume no tracing

TRACE=0

# more fun with port #s: 22439 = 0x57A7 ('STAT')

PORT=22439

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

Usage: runMotusStatusServer2.sh [-h] [-t] [-p PORT]

Run the motus status server (API version) which replies to requests
for job and server status.

   -h  show usage

   -t  enable tracing, so run in foreground.  Program will enter the
       debugger before each job step.

   -p PORT listen on local port PORT; default: 22439

EOF
            exit 1;
            ;;
        esac
    shift
done

export SPID=$$;

PIDFILE=/sgm/statusServer2.pid
if [[ -s $PIDFILE ]]; then
    OLDPID=`cat $PIDFILE`
    if [[ -d /proc/$OLDPID ]]; then
        cat <<EOF

There is already a motus status server (API version) running, so I won't start
another.  In the current design, the status server (API version) is a singleton.

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
    echo `date +%Y-%m-%dT%H-%M-%S.%6N`: "Status server (API version) killed." >> /sgm/logs/mainlog.txt
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
        nohup Rscript -e "library(motusServer);statusServer2(port=$PORT, tracing=FALSE)" >> /sgm/logs/status2.txt 2>&1
        sleep 15
    done
else
    MYTMPDIR=`mktemp -d`
    cd $MYTMPDIR
    ## set up an .Rprofile; because loading of the usual libraries
    ## happens after .Rprofile is eval'd, they won't have been loaded
    ## when statusServer2 is called, so load them manually
    cat <<EOF > .Rprofile
    for (l in c("datasets", "utils", "grDevices", "graphics", "stats", "motusServer"))
        library(l, character.only=TRUE)
    rm(l)
    options(error=recover)
    statusServer2(port=$PORT, tracing=TRUE)
EOF
    R
fi
