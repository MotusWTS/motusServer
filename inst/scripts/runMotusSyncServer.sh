#!/bin/bash
#
# run the motus sync server
#

# assume no tracing

TRACE=0

while [[ "$1" != "" ]]; do
    case "$1" in
        -t)
            TRACE=1
            ;;
        -h|*)
            cat <<EOF

Usage: runMotusSyncServer.sh [-h] [-t]

Run the motus sync server which periodically grabs files from
attached receivers.

   -h  show usage

   -t  enable tracing, so run in foreground.  Program will enter the
       debugger before each job step.

EOF
            exit 1;
            ;;
        esac
    shift
done

export SPID=$$;

PIDFILE=/sgm/syncServer.pid
if [[ -s $PIDFILE ]]; then
    OLDPID=`cat $PIDFILE`
    if [[ -d /proc/$OLDPID ]]; then
        cat <<EOF

There is already a motus sync server running, so I won't start
another.

EOF
        exit 1;
    fi
    echo $SPID > $PIDFILE
fi

## restart the process whenever it dies, allowing a
## short interval to prevent thrashing

function onExit {
## cleanup the pid file, and possibly the temporary R file
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

## for now, killFile functionality is disabled

## killFile=/sgm/sync/kill
## rm -f $killFile

if [[ $TRACE == 0 ]]; then
    while (( 1 )); do
        nohup Rscript -e 'library(motusServer);syncServer(tracing=FALSE)' >> /sgm/logs/sync.log.txt 2>&1
        ## Kill off the inotifywait process; it's in our process group.
        ## This should happen internally, but might not.
        pkill -g $$ inotifywait

        # ## check for a file called $killFile, and if it exists, delete it and quit
        # if [[ -f $killFile ]]; then
        #     rm -f $killFile
        #     exit 0
        # fi
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
    syncServer(tracing=TRUE)
EOF
    R
    pkill -g $$ inotifywait
fi
