#!/bin/bash
#
# run all motus servers, with N process servers; default N=4
#

if [[ "$UID" == "0" ]]; then

    cat <<EOF

Refusing to run servers as root.  Please run as user `sg`.

EOF
    exit 1
fi

if [[ "$1" == "-h" ]]; then

    cat <<EOF

Usage: runAllMotusServers.sh [-h] [-s] [N]

Run all motus servers by invoking these scripts:

   - runMotusStatusServer.sh
   - runMotusStatusServer2.sh
   - runMotusDataServer.sh
   - runMotusProcessServer.sh 1
   - runMotusProcessServer.sh 2
     ...
   - runMotusProcessServer.sh N
   - runMotusProcessServer.sh 101
   - runMotusProcessServer.sh 102
   - runMotusProcessServer.sh 103
   - runMotusProcessServer.sh 104
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
    sqlite3 /sgm_local/server.sqlite "delete from symLocks"
    shift
fi

N=4
if [[ "$1" != "" ]]; then
    N=$1
fi

## use 'setsid' to launch each server in its own process group

setsid /sgm_local/bin/runMotusStatusServer.sh &
setsid /sgm_local/bin/runMotusStatusServer2.sh &
setsid /sgm_local/bin/runMotusDataServer.sh &

## >= 100 is the priority server, for short fast jobs; they won't
## run uploaded data, but do handle syncReceiver jobs.

for i in `seq 1 $N` 101 102 103 104; do
    setsid /sgm_local/bin/runMotusProcessServer.sh $i &
done
setsid /sgm_local/bin/runMotusSyncServer.sh &

echo "Started status, status2, data, sync and $N + 4 process servers, four for high-priority jobs."
