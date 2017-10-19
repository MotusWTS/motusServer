#!/bin/bash
# backup an sqlite database
#
# incrementally copies each table from a source to a destination database
# in small chunks, with a sleep between each chunk to allow other processes
# to access the source DB.
#
# Only works with rowid tables, since rowid is used to paginate into chunks.
#
# Usage:  backup_sqlite_db.s SRC DEST CHUNK_ROWS
#
SRC="$1"
DEST="$2"

if [[ "$SRC" == "" || "$DEST" == "" ]]; then
   echo missing SRC or DEST database
   exit 1
fi
CHUNK_ROWS=$3
if [[ $CHUNK_ROWS == "" ]]; then
    CHUNK_ROWS=5000
fi

TABLES=`sqlite3 $SRC .tables`

for t in $TABLES; do
    echo backing up table $t

    NEWMAXROWID=`sqlite3 $SRC <<EOF
ATTACH DATABASE '$DEST' AS d;
CREATE TABLE IF NOT EXISTS d.$t AS SELECT $t.* from $t ORDER BY ROWID LIMIT $CHUNK_ROWS;
SELECT max(rowid) from d.$t;
DETACH DATABASE d;
EOF`
    MAXROWID=""
    while [[ "$MAXROWID" != "$NEWMAXROWID" ]]; do
        MAXROWID=$NEWMAXROWID
        NEWMAXROWID=`sqlite3 $SRC <<EOF
ATTACH DATABASE '$DEST' AS d;
INSERT INTO d.$t SELECT $t.* from $t where rowid > $MAXROWID ORDER BY ROWID LIMIT $CHUNK_ROWS;
SELECT max(rowid) from d.$t;
DETACH DATABASE d;
EOF`
        sleep 0.1
    done
done
