#!/bin/bash

# check the username and group number against the values returned by
# the motus API.  If valid, exit with code 0; otherwise, exit with
# code 1.

USERDB=/sgm/userauth/userauth.sqlite

read LOGIN
read GROUP
LOGIN=${LOGIN//\'/\\\'}
mapfile -t GRP < <( sqlite3 $USERDB "pragma busy_timeout=30000;select json_extract(groups,'$.$GROUP') from userauth where login='$LOGIN'" )
if [[ "${GRP[1]}" != "" ]]; then
    exit 0;
fi
exit 1;
