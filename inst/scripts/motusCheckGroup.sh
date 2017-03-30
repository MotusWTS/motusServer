#!/bin/bash

# check the username and group number against the values returned by
# the motus API.  If valid, exit with code 0; otherwise, exit with
# code 1.

USERDB=/sgm/userauth/userauth.sqlite

read LOGIN
# escape single quotes in username, for sqlite
LOGIN=${LOGIN//\'/\\\'}

# there might be multiple groups permitted for the directory being checked
read -a GROUP

# generate a query like this:
#    select ifnull(json_extract(groups, "$.${GROUP[0]}"), "")
#        || ifnull(json_extract(groups, "$.${GROUP[1]}"), "")
#        ...
#    from userauth where login="$LOGIN"

QUERY=""
for G in "${GROUP[@]}"; do
    if [[ "$QUERY" != "" ]]; then
        QUERY="$QUERY || "
    fi
    QUERY="${QUERY}ifnull(json_extract(groups, '$.$G'), '')";
done
mapfile -t GRP < <( sqlite3 $USERDB "pragma busy_timeout=30000;select $QUERY from userauth where login='$LOGIN'" )

# if the query succeded in getting anything other than an empty string, it's because
# the user belongs to one of the groups in $GROUP
# Note: ${GRP[0]} is the result of the pragma, so use ${GRP[1]}

if [[ "${GRP[1]}" != "" ]]; then
    exit 0;
fi
exit 1;
