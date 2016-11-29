#!/bin/bash
#
# run the motus email server
#

# assume no tracing

rm -f /sgm/EMBARGO
TRACE=0

while [[ "$1" != "" ]]; do
    case "$1" in
        -e)
            printf "Presence of this file prevents new emails from being processed,\ndiverting them to /sgm/embargoed_inbox instead.\n" > /sgm/EMBARGO
            ;;
        -t)
            TRACE=1
            ;;
        -h|*)
            cat <<EOF

Usage: runMotusEmailServer.sh [-h] [-e] [-t]

Run the motus email server which processes incoming data emails.

   -h  show usage

   -e  embargo; do not process new emails.  Normally, emails are moved
       to /sgm/inbox as received.  With this option, emails are
       written to /sgm/embargoed_inbox instead, which prevents them
       from being processed.

   -t  enable tracing, so run in foreground.  Program will enter the
       debugger before each job step.

EOF
            exit 1;
            ;;
        esac
    shift
done

PIDFILE=/sgm/emailServer.pid
if [[ -s $PIDFILE ]]; then
    OLDPID=`cat $PIDFILE`
    if [[ -d /proc/$OLDPID ]]; then
        cat <<EOF

There is already a motus email server running, so I won't start
another.  In the current design, the email server is a singleton, on
the assumption that network bandwidth on our end is the limiting
factor when the server is busy.

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
    echo Email server stopped. >> /sgm/logs/mainlog.txt
}

## call the cleanup handler on exit

trap onExit EXIT

echo $$ > $PIDFILE

if [[ $TRACE == 0 ]]; then
    while (( 1 )); do
        nohup Rscript -e 'library(motusServer);emailServer(tracing=FALSE)'
        ## Kill off the inotifywait process; it's in our process group.
        ## This should happen internally, but might not.
        pkill -g $$ inotifywait

        ## check for a file called $killFile, and if it exists, delete it and quit
        if [[ -f $killFile ]]; then
            echo Email server detected file $killFile. >> /sgm/logs/mainlog.txt
            rm -f $killFile
            exit 0
        fi
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
    emailServer(tracing=TRUE)
EOF
    R
    pkill -g $$ inotifywait
fi
