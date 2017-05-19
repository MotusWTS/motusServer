#!/bin/bash

# check the username, password pair against the motus API
# If valid, exit with code 0; otherwise, exit with code 1.

USERDB=/sgm/userauth/userauth.sqlite
DATE=`date -u +%Y%m%d%H%M%S`
read LOGIN
read PWORD
printf -v JSON '{"date":"%s","login":"%s","pword":"%s", "type":"csv"}' "$DATE" "$LOGIN" "$PWORD"
RESP=`curl -s --data-urlencode "json=$JSON" https://motus.org/api/user/validate`
if [[ "$RESP" =~ "userID" ]]; then
    LOGIN=${LOGIN//\'/\'\'};
    RESP=${RESP//\'/\'\'};
    echo "pragma busy_timeout=30000;create table if not exists userauth (login text unique primary key, userid integer, groups text);\
          replace into userauth (login, groups) values ('$LOGIN', '$RESP');\
          update userauth set userid=json_extract(groups, '$.userID'), groups=json_extract(groups, '$.projects') where login='$LOGIN';" | sqlite3 $USERDB > /dev/null
    exit 0;
fi
exit 1;
