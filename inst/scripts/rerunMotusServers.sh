#!/bin/bash
#
# rerun all motus servers, once current servers have been killed,
# possibly gracefully.
#

if [[ "$1" != "-f" && "$1" != "-g" ]]; then

    cat <<EOF

Usage: rerunMotusServers.sh (-f | -g)

Kill all motus servers, then restart them.
One of these options must be specified:

 -f: kill servers forcefully, preventing their current job from completing

 -g: kill servers gracefully, allowing their current jobs to complete, but no
     new jobs to be run from the queue.

This script is meant for restarting servers after a new version of the
motusServer package is installed, because a running R with packages
already loaded won't use the new version of the package.

When using "-g", the check for any still-running servers is performed
every 10 seconds.

EOF
    exit 1

fi

if [[ "$1" == "-g" ]]; then
    GRACEFUL="-g"
else
    GRACEFUL=""
fi

/sgm/bin/killAllMotusServers $GRACEFUL

## if a graceful shutdown, wait until all .pid files
## have been deleted, indicating the corresponding
## process has ended.

if [[ $GRACEFUL ]]; then
    while (( 1 )); do
        if [[ `ls -1 /sgm/*.pid 2>/dev/null` == "" ]]; then
            break
        fi
        sleep 10
    done
fi

/sgm/bin/runAllMotusServers.sh
