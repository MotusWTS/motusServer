#!/bin/bash
#
# run all motus servers, with N process servers; default N=4
#

if [[ "$1" == "-h" ]]; then

    cat <<EOF

Usage: runAllMotusServers.sh [-h] [N]

Run all motus servers by invoking these scripts:

   - runMotusEmailServer.sh

   - runMotusStatusServer.sh

   - runMotusProcessServer.sh 1
   - runMotusProcessServer.sh 2
     ...
   - runMotusProcessServer.sh N

Defaults to N=4.

Specifying -h gives this message.

EOF
    exit 1

fi

N=4
if [[ "$1" != "" ]]; then
    N=$1
fi

setsid /sgm/bin/runMotusEmailServer.sh &
setsid /sgm/bin/runMotusStatusServer.sh &
for i in `seq 1 $N`; do
    setsid /sgm/bin/runMotusProcessServer.sh $i &
done

echo "Started email server, status server, and $N process server(s)."
