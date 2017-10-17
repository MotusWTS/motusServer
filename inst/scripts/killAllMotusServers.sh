#!/bin/bash
#
# kills all motus servers
#

if [[ "$1" == "-h" ]]; then

    cat <<EOF

Usage: killAllMotusServers.sh [-h] [-g]

Kills all motus servers by invoking these scripts:

   - killMotusUploadServer.sh

   - killMotusStatusServer.sh

   - killMotusStatusServer2.sh

   - killMotusDataServer.sh

   - killMotusSyncServer.sh

   - killMotusProcessServer.sh -a [-g]

Specifying -g means graceful: processServers stop
after completing their current subjob, others after completing
their current request.  This flag is passed to
killMotusDataServer.sh, killMotusStatusServer, and killMotusProcessServer.sh

Specifying -h gives this message.

EOF

    exit 1;
fi

GRACEFUL=""
if [[ "$1" == "-g" ]]; then
    GRACEFUL="-g"
fi

/sgm/bin/killMotusUploadServer.sh
/sgm/bin/killMotusStatusServer.sh $GRACEFUL
/sgm/bin/killMotusStatusServer2.sh $GRACEFUL
/sgm/bin/killMotusDataServer.sh $GRACEFUL
/sgm/bin/killMotusSyncServer.sh
/sgm/bin/killMotusProcessServers.sh -a $GRACEFUL


echo Killed upload, status, data and all process servers.
