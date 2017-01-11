#!/bin/bash
if [[ "$1" == "" ]]; then
    cat <<EOF
Usage: $0 SERNO

where SERNO is a full or partial SG serial number.  Prints the list of tunnel ports
assigned to receivers whose serial number matches SERNO.
EOF

    exit 0
fi
sqlite3 /sgm/remote/receivers.sqlite "select serno, tunnelPort from receivers where serno glob '*$1*';"
