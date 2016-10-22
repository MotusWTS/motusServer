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

   -h : show usage

   -e : embargo; do not process new emails.  Normally, emails are
        moved to /sgm/inbox as received.  With this option, emails are
        written to /sgm/embargoed_inbox instead, which prevents them
        from being processed.

   -t enable tracing, so run in foreground.  Program will enter the
      debugger before each job step.

EOF
            exit 1;
            ;;
        esac
    shift
done

## restart the process whenever it dies, allowing a
## short interval to prevent thrashing

echo $$ > /sgm/emailServer.pid

if [[ $TRACE == 0 ]]; then
    while (( 1 )); do
        nohup Rscript -e 'library(motus);emailServer(tracing=FALSE)'
        ## kill off the inotifywait process; it's in our process group
        ## this should happen internally, but might not
        pkill -g $$ inotifywait
        sleep 15
    done
else
    cd `mktemp -d`
    echo "library(motus); options(error=recover); emailServer(tracing=TRUE)" > .Rprofile
    R
fi
