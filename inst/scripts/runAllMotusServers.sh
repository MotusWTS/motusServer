#!/bin/bash
#
# run all motus servers, with N process servers; default N=4
#

if [[ "$1" == "-h" ]]; then

    cat <<EOF

Usage: runAllMotusServers.sh [-h] [-s] [N]

Run all motus servers by invoking these scripts:

   - runMotusUploadServer.sh

   - runMotusStatusServer.sh
   - runMotusStatusServer2.sh

   - runMotusProcessServer.sh 1
   - runMotusProcessServer.sh 2
     ...
   - runMotusProcessServer.sh N
   - runMotusProcessServer.sh 101
   - runMotusProcessServer.sh 102
   - runMotusSyncServer.sh

Defaults to N=4.

Specifying -h gives this message.

Specifying -s forces deletion of all entries in the server's symLocks table.
This should be used at boot time, and only at boot time, to delete stale locks
from an unclean shutdown (e.g. power outage).

Note:

EOF
    exit 1

fi

if [[ "$1" == "-s" ]]; then
    sqlite3 /sgm/server.sqlite "delete from symLocks"
    shift
fi

N=4
if [[ "$1" != "" ]]; then
    N=$1
fi

## use 'setsid' to launch each server in its own process group

setsid /sgm/bin/runMotusUploadServer.sh &
setsid /sgm/bin/runMotusStatusServer.sh &
setsid /sgm/bin/runMotusStatusServer2.sh &
setsid /sgm/bin/runMotusDataServer.sh &

## '99' is the priority server, for short fast jobs; it won't
## run uploaded data.

for i in `seq 1 $N` 101 102; do
    setsid /sgm/bin/runMotusProcessServer.sh $i &
done
setsid /sgm/bin/runMotusSyncServer.sh &

echo "Started upload, status, data, sync and $N + 2 process servers, two for high-priority jobs."
