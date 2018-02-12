#!/bin/bash
# backup an sqlite database
#
# incrementally copies each table from a source to a destination database
# in small chunks, with a sleep between each chunk to allow other processes
# to access the source DB.
#
# Only works with rowid tables, since rowid is used to paginate into chunks.
#
# Doesn't necessarily capture original column affinities, and doesn't
# create indexes.
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

    ## copy in batches, paging by rowid of source table
    ## Note:  rowids in source and dest tables might not agree because
    ## rows in source table might have been deleted (meaning rowids need
    ## not be a contiguous set starting at 1), while dest table
    ## is being created from scratch, so rowids *are* a contiguous set
    ## starting at 1.

    ## Also, to make sure we're selecting the correct max(rowid), we
    ## wrap the two queries (one to get data, another to get the max rowid)
    ## in a transaction.

    NEWMAXROWID=`sqlite3 $SRC <<EOF
PRAGMA BUSY_TIMEOUT = 30000;
ATTACH DATABASE '$DEST' AS d;
BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS d.$t AS SELECT $t.* from $t ORDER BY ROWID LIMIT $CHUNK_ROWS;
SELECT max(rowid) FROM $t ORDER BY ROWID LIMIT $CHUNK_ROWS ;
COMMIT;
DETACH DATABASE d;
EOF`
    MAXROWID=""
    while [[ "$MAXROWID" != "$NEWMAXROWID" ]]; do
        MAXROWID=$NEWMAXROWID
        NEWMAXROWID=`sqlite3 $SRC <<EOF
PRAGMA BUSY_TIMEOUT = 30000;
ATTACH DATABASE '$DEST' AS d;
BEGIN TRANSACTION;
INSERT INTO d.$t SELECT $t.* from $t where rowid > $MAXROWID ORDER BY ROWID LIMIT $CHUNK_ROWS;
SELECT max(rowid) from $t where rowid > $MAXROWID ORDER BY ROWID LIMIT $CHUNK_ROWS;
COMMIT;
DETACH DATABASE d;
EOF`
        sleep 0.1
    done
done
