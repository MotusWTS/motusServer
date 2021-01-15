#!/bin/bash
#
# kills all motus servers
#

if [[ "$1" == "-h" ]]; then

    cat <<EOF

Usage: killAllMotusServers.sh [-h] [-g]

Kills all motus servers by invoking these scripts:

   - killMotusStatusServer.sh

   - killMotusStatusServer2.sh

   - killMotusDataServer.sh

   - killMotusSyncServer.sh

   - killMotusProcessServer.sh -a [-g]

Specifying -g means graceful: processServers stop
after completing their current subjob, others after completing
their current request.  This flag is passed to
killMotusDataServer.sh, killMotusStatusServer, and killMotusProcessServer.sh

Only data and status2 servers running on default ports are killed.

Specifying -h gives this message.

EOF

    exit 1;
fi

GRACEFUL=""
if [[ "$1" == "-g" ]]; then
    GRACEFUL="-g"
fi

/sgm/bin/killMotusSyncServer.sh
/sgm/bin/killMotusProcessServers.sh -a $GRACEFUL

## if a graceful shutdown, wait until all .pid files
## have been deleted, indicating the corresponding
## process has ended.

if [[ $GRACEFUL ]]; then
    while (( 1 )); do
        if [[ `ls -1 /sgm/*.pid | grep processServer 2>/dev/null` == "" ]]; then
            break
        fi
        printf "Sleeping 10s while waiting for:\n`cd /sgm; ls -1 *.pid | grep processServer | sed -e 's/.pid//'`\nto finish current job(s).\n"
        sleep 10
    done
fi

/sgm/bin/killMotusDataServer.sh $GRACEFUL
/sgm/bin/killMotusStatusServer.sh $GRACEFUL
/sgm/bin/killMotusStatusServer2.sh $GRACEFUL


echo Killed status, status2, data and all process servers.
