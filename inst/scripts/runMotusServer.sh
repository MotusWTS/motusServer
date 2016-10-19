#!/bin/bash

if [[ "$1" == "-h" ]]; then cat <<EOF

Usage: runMotusServer.sh [-h]

Run the motus server which handles incoming data emails and other
moves of data to /sgm/incoming

-h : show usage

EOF
    exit 1;
fi

## restart the process whenever it dies, allowing a
## short interval to prevent thrashing

echo $$ > /sgm/server.pid

while (( 1 )); do
   nohup Rscript -e 'library(motus);server(tracing=FALSE)'
## kill off the inotifywait process; it's in our process group
   pkill -g $$ inotifywait
   sleep 15
done
