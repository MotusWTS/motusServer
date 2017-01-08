#!/bin/bash
#
# kills all motus servers
#

if [[ "$1" == "-h" ]]; then

    cat <<EOF

Usage: killAllMotusServers.sh [-h] [-g]

Kills all motus servers by invoking these scripts:

   - killMotusEmailServer.sh [-g]

   - killMotusUploadServer.sh

   - killMotusStatusServer.sh

   - killMotusSyncServer.sh

   - killMotusProcessServer.sh -a [-g]

Specifying -g means graceful: processServers and the emailServer stop
after completing their current subjob.  This flag is passed to
killMotusEmailServer.sh and killMotusProcessServer.sh

Specifying -h gives this message.

EOF

    exit 1;
fi

GRACEFUL=""
if [[ "$1" == "-g" ]]; then
    GRACEFUL="-g"
fi

/sgm/bin/killMotusEmailServer.sh $GRACEFUL
/sgm/bin/killMotusUploadServer.sh
/sgm/bin/killMotusStatusServer.sh
/sgm/bin/killMotusSyncServer.sh
/sgm/bin/killMotusProcessServers.sh -a $GRACEFUL


echo Killed email, upload, status and all process servers.
