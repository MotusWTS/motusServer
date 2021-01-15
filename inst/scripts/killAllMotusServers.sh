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
/sgm/bin/killMotusDataServer.sh $GRACEFUL
/sgm/bin/killMotusStatusServer.sh $GRACEFUL
/sgm/bin/killMotusStatusServer2.sh $GRACEFUL


echo Killed status, status2, data and all process servers.
