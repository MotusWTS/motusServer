#!/bin/bash
#
# kills all motus servers
#

if [[ "$1" == "-h" ]]; then

    cat <<EOF

Usage: killAllMotusServers.sh [-h]

Kills all motus servers by invoking these scripts:

   - killMotusEmailServer.sh

   - killMotusStatusServer.sh

   - killMotusProcessServer.sh -a

Specifying -h gives this message.

EOF

    exit 1;
fi

/sgm/bin/killMotusEmailServer.sh
/sgm/bin/killMotusStatusServer.sh
/sgm/bin/killMotusProcessServers.sh -a

echo Killed email server, status server, and all process servers.
