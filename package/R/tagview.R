#' tagview create a view of tag detections linked to all metadata.
#'
#' This function returns data_frames of tag detections.  These can
#' come from receiver databases or tag databases.  Metadata for projects,
#' tag, and receiver deployments are linked when available.
#'
#' @param db dplyr src_sqlite to detections database, or path to
#'     .sqlite file.  The database must have tables batches, hits,
#'     runs.
#'
#' @param dbMeta dplyr src to database with "tags", "projects",
#'     "species", and "recvDeps" tables.  Default: \code{db}
#'
#' @param minRunLen minimum number of hits in a run; runs with fewer
#'     hits are dropped
#'
#' @param keep should temporary tables be saved permanently in the
#'     detections database?
#'
#' Default: FALSE.  See Note below.
#'
#' @return a read-only data_frame of tag detections.  This data_frame
#'     is an SQLite VIEW wrapped in a dplyr tbl(), and "lives" in
#'  the \code{db} object.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

#' Implementation details:
#'
#' For both tags and receivers, deployment meta-data has to be looked up by hit timestamp;
#' i.e. we need the latest deployment record which is earlier than the hit timestamp.
#' i.e. we are joining the hit table to the tag deployment table by a timestamp on the hit
#' and a greatest lower bound for that timestamp in the deployment table.
#' It would be nice if there were an SQL "LOWER JOIN" operator, which instead of joining
#' on exact key value, would join a key on the left to its greatest lower bound on the right.
#' (and similary, an "UPPER JOIN" operator to bind to the least upper bound on the right.)
#' For keys with B-tree indexes, this would be as fast as an exact join.
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
#' This will yield NA for the 'info' field when there is no tag deployment covering the range.
#' Running EXPLAIN on this query in sqlite suggests it optimizes well.

tagview = function(db, dbMeta=db, minRunLen=3, keep=TRUE) {

    ## convert any paths to src_sqlite

    for (n in c("db", "dbMeta"))
        if (! inherits(get(n), "src_sqlite"))
            assign(n, src_sqlite(get(n)))

    ## copy needed tables from dbMeta to temporary db on same connection as db
    n = src_tbls(db)

    for (t in c("tags", "tagDeps", "recvDeps", "antDeps", "species", "projs")) {
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

    if (dbExistsTable(db$con, "tagAmbig") && isTRUE(unlist(dbGetQuery(db$con, "select count(*) from tagAmbig")) > 0)) {
        ## join all tag deployment records for the ambiguity
        dbGetQuery(db$con, "CREATE TEMPORARY VIEW _ambigjoin AS SELECT t1.ambigID, t2.tagID, t2.tsStart, t2.fullID FROM tagAmbig AS t1 JOIN tagDeps AS t2 ON t2.tagID IN (t1.motusTagID1, t1.motusTagID2, t1.motusTagID3, t1.motusTagID4, t1.motusTagID5, t1.motusTagID6) ORDER BY t1.ambigID, t2.tsStart;")

        ## remove any existing deployment records for these ambiguities
        dbGetQuery(db$con, "DELETE FROM tagDeps WHERE tagID IN (SELECT ambigID FROM tagAmbig);")

        ## create temporary ambiguity deployment records with a pasted fullID which we fix inside R

        ambigdeps = dbGetQuery(db$con, "SELECT ambigID, max(tsStart) as tsStart, group_concat(fullID) as fullID FROM _ambigjoin GROUP BY ambigID;")

        for (i in 1:nrow(ambigdeps)) {
            parts = unique(strsplit(ambigdeps$fullID[i], ",", fixed=TRUE)[[1]])
            ambigdeps$fullID[i] = paste0(paste(sub("#.*", "", perl=TRUE, parts), collapse=" or "), "#", sub(".*#", "", perl=TRUE, parts[1]))
        }
        dbWriteTable(db$con, "_ambigdeps", ambigdeps, overwrite=TRUE, row.names=FALSE)
        dbGetQuery(db$con, "insert into tagDeps (tagID, tsStart, fullID) select * from _ambigdeps;")
        dbGetQuery(db$con, "drop table _ambigdeps;");
    }

    query = "
CREATE VIEW allt AS SELECT
t1.*, t2.*, t3.*, t4.*, t5.*, t6.*, t7.*, t8.*, t9.*, t10.* FROM
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
LEFT JOIN projs    AS t10 ON t10.ID        = t6.projectID
"
    dbGetQuery(db$con, "DROP VIEW IF EXISTS allt")
    dbGetQuery(db$con, query)
    return(tbl(db, "allt"))
}
