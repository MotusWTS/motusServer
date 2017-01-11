#' create a tbl of tag detections with all metadata.
#'
#' Creates a view (called 'bfj' for 'Big Fat Join') of tag detections
#' from a motus database and associated metadata for projects, tags
#' and receivers, where available.  The view is wrapped in a
#' dplyr::tbl to ease use with the dplyr package, but is also
#' available directly from the underlying SQLite connection, where
#' it can appear in sql statements such as \code{select * from bfj}.
#'
#' @param db dplyr src_sqlite to detections database, or path to
#'     .sqlite file.  The database must have tables batches, hits,
#'     runs.
#'
#' @param dbMeta dplyr src to database with "tags", "projects",
#'     "species", and "recvDeps" tables.  Default: \code{db}
#'
#' @param mobile logical or NULL (the default); determines the source
#'     of GPS fixes for tag detections.  Possible values are:
#'
#' \itemize{
#'
#' \item NULL: use whatever GPS records are available in the recvGPS
#'     meta-data table.  For tagProject databases, this will be a
#'     nominal lat/lon for fixed deployments, and a time series of GPS
#'     fixes for mobile deployments.  This is usually what you want.
#'
#' \item FALSE: use only the nominal deployment lat/lon.  This runs
#'     faster, but will give incorrect lat/lon for mobile deployments.
#'
#' \item TRUE: if this is a receiver motus database, as opposed to a
#'     tagProject database, then use the most recent fix table from
#'     the receiver's GPS table, regardless of whether the receiver
#'     deployment is considered "mobile".  Use this if you are looking
#'     at data from a single receiver and you want to treat it as
#'     mobile, even if motus.org does not think it was "mobile".  For
#'     a tagProject database, this values is treated the same as NULL.
#'
#' }
#'
#' @param keep should temporary tables be saved permanently in the
#'     detections database?  Default: FALSE.  If true, subsequent
#' calls to this function for the same detection database won't need
#' the \code{dbMeta} database, because all metadata will have been
#' copied to \code{db}.
#'
#' @return a read-only dplyr::tbl of tag detections.  This tbl
#'     is an SQLite VIEW wrapped in a dplyr::tbl(), and "lives" in the
#'     \code{db} object.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'
#' Implementation details:
#'
#' For both tags and receivers, deployment meta-data has to be looked
#' up by detection ("hit") timestamp; i.e. we need the latest
#' deployment record which is still before the hit timestamp.  So we
#' are joining the hit table to the deployment table by a timestamp on
#' the hit and a greatest lower bound for that timestamp in the
#' deployment table.  It would be nice if there were an SQL
#' "LOWER JOIN" operator, which instead of joining on exact key value,
#' would join a key on the left to its greatest lower bound on the
#' right.  (and similary, an "UPPER JOIN" operator to bind to the
#' least upper bound on the right.)  For keys with B-tree indexes,
#' this would be as fast as an exact join.
#'
#' We can instead code this as a subquery like so:
#'
#' CREATE TABLE hits (ts double, tagID integer);
#' CREATE TABLE tagDeps (tsStart double, tsEnd double, tagID integer, info char);
#'
#'    SELECT t1.*, t2.info from hits as t1 left join tagDeps as t2 on
#'    t2.tagID = t1.tagID and t2.tsStart = (select max(t3.tsStart) from
#'    tagDeps as t3 where t3.tagID=t2.tagID and t3.tsStart <= t1.ts and
#'    t3.tsEnd >= t1.ts)
#'
#' This will yield NA for the 'info' field when there is no tag
#' deployment covering the range.  Running EXPLAIN on this query in
#' sqlite suggests it optimizes well.
#'
#' GPS fixes
#'
#' If this is a receiver database (with detections from a single receiver),
#' it will contain a table called \code{GPS} with receiver GPS fixes, and these
#' are used in the view to provide lat/lon/elevation.
#'
#' Otherwise, lat/lon/elevation come from the recvGPS table.  For most receiver
#' deployments, that table will contain only one fix, but for mobile deployments,
#' the table will contain a time series of fixes.  The view will use this table
#' to provide lat/lon/elevation.

tagview = function(db, dbMeta=db, mobile=NULL, keep=FALSE) {

    ## convert any paths to src_sqlite

    for (n in c("db", "dbMeta"))
        if (! inherits(get(n), "src_sqlite"))
            assign(n, src_sqlite(get(n)))

    ## copy needed tables from dbMeta to temporary db on same connection as db
    ## FIXME: copy only those records needed for the tags

    n = src_tbls(db)

    for (t in c("tags", "tagDeps", "recvDeps", "recvGPS", "antDeps", "species", "projs")) {
        if (t %in% n)
            dbGetQuery(db$con, paste("drop table", t))
        copy_to(db, tbl(dbMeta,t) %>% collect, t, temporary= ! keep)
    }

    ## For each tag ambiguity, we want a tag deployment record that
    ## provides an appropriate start date and label for the
    ## ambiguity. If a tag in an ambiguity has multiple deployment
    ## records, we need a tag ambiguity deployment record for each.
    ## So for all combinations of deployment records for tags in an
    ## ambiguity group, we need a separate tag deployment record.
    ##
    ## e.g. suppose tags 10000 and 10001 form amibiguity # -10
    ##
    ## Suppose we have these deployment records:
    ##   tagID   project   start
    ##  10000     Mary     2015-01-01
    ##  10000     Bill     2015-03-01
    ##  10001     Frank    2015-02-01
    ##  10001     Jill     2015-02-15
    ##
    ## Timeline:
    ##
    ##      10000_Mary------------------------------------10000_Bill-------->
    ##                       10001_Frank--10001_Jill------------------------>
    ## -----+----------------+------------+---------------+----------------->
    ##      01-01            02-01        02-15           03-01
    ##
    ## We want these tagDeps records:
    ##
    ##  tagID    label (project only)  start
    ##   -10     Mary or Frank        2015-02-01
    ##   -10     Mary or Jill         2015-02-15
    ##   -10     Bill or Jill         2015-03-01

    ## generate appropriate tagDeps records; each will have:
    ##
    ## - ambigID: negative bogus tag ID
    ##
    ## - fullID: pasted fullIDs, removing duplicate suffix like so:
    ##    "Charley#45:8.1@166.38", "Baker#45:8.1@166.38" -> "Charley or Baker#45:8.1@166.38"
    ##
    ## - tsStart: maximum start time of any of the ambiguous tags

    if (dbExistsTable(db$con, "tagAmbig") && dbGetQuery(db$con, "select count(*) from tagAmbig") [[1]] > 0) {
        ## join all tag deployment records for the ambiguity
        dbGetQuery(db$con, "CREATE TEMPORARY VIEW _ambigjoin AS SELECT t1.ambigID, t2.tagID, t2.tsStart, t2.fullID FROM tagAmbig AS t1 JOIN tagDeps AS t2 ON t2.tagID IN (t1.motusTagID1, t1.motusTagID2, t1.motusTagID3, t1.motusTagID4, t1.motusTagID5, t1.motusTagID6) ORDER BY t1.ambigID, t2.tsStart;")

        ## remove any existing deployment records for these ambiguities
        dbGetQuery(db$con, "DELETE FROM tagDeps WHERE tagID IN (SELECT ambigID FROM tagAmbig);")

        ## create temporary ambiguity deployment records with a pasted fullID which we fix inside R

        ambigdeps = dbGetQuery(db$con, "SELECT ambigID, max(tsStart) as tsStart, group_concat(fullID) as fullID FROM _ambigjoin GROUP BY ambigID;")
        dbGetQuery(db$con, "DROP VIEW _ambigjoin;")

        for (i in 1:nrow(ambigdeps)) {
            parts = unique(strsplit(ambigdeps$fullID[i], ",", fixed=TRUE)[[1]])
            ambigdeps$fullID[i] = paste0(paste(sub("#.*", "", perl=TRUE, parts), collapse=" or "), "#", sub(".*#", "", perl=TRUE, parts[1]))
        }
        dbWriteTable(db$con, "_ambigdeps", ambigdeps, overwrite=TRUE, row.names=FALSE)
        dbGetQuery(db$con, "insert into tagDeps (tagID, tsStart, fullID) select * from _ambigdeps;")
        dbGetQuery(db$con, "drop table _ambigdeps;");
    }

    map = getMap(db)
    query = paste0("
CREATE", if (! keep) " TEMPORARY" else "", " VIEW bfj AS SELECT
t1.*, t2.*, t3.*, t4.*, t5.*, t6.*, t7.*, t8.*, t9.*, t10.*, t11.* FROM

hits AS t1

LEFT JOIN runs     AS t2  ON t1.runID      = t2.runID

LEFT JOIN batches  AS t3  ON t3.batchID    = t1.batchID

LEFT JOIN tags     AS t4  ON t4.tagID      = t2.motusTagID

LEFT JOIN tagDeps  AS t5  ON t5.tagID      = t2.motusTagID  AND
                             t5.tsStart    = (SELECT max(t5b.tsStart) FROM tagDeps AS t5b
                                              WHERE t5b.tagID = t2.motusTagID
                                              AND t5b.tsStart <= t1.ts
                                              AND (t5b.tsEnd IS NULL OR t5b.tsEnd >= t1.ts))

LEFT JOIN recvDeps AS t6  ON t6.deviceID   = t3.motusDeviceID AND
                             t6.tsStart    = (SELECT max(t6b.tsStart) FROM recvDeps AS t6b
                                              WHERE t6b.deviceID=t3.motusDeviceID
                                              AND t6b.tsStart <= t1.ts
                                              AND (t6b.tsEnd IS NULL OR t6b.tsEnd >= t1.ts))

LEFT JOIN antDeps  AS t7  ON t7.deployID   = t6.deployID    AND t7.port = t2.ant
LEFT JOIN species  AS t8  ON t8.id         = t5.speciesID
LEFT JOIN projs    AS t9  ON t9.ID         = t5.projectID
LEFT JOIN projs    AS t10 ON t10.ID        = t6.projectID ",

if (isTRUE(mobile) && map$dbType == "receiver") {
"LEFT JOIN gps AS t11  ON t11.ts = (SELECT max(t11b.ts) FROM gps AS t11b
                                              where t11b.ts <= t1.ts)
"
} else {
"LEFT JOIN recvGPS AS t11  ON t11.deviceID   = t3.motusDeviceID AND
                              t11.ts         = (SELECT max(t11b.ts) FROM recvGPS AS t11b
                                               WHERE t11b.deviceID=t3.motusDeviceID
                                               AND t11b.ts <= t1.ts)
"
}
)
    dbGetQuery(db$con, "DROP VIEW IF EXISTS bfj")
    dbGetQuery(db$con, query)
    return(tbl(db, "bfj"))
}
