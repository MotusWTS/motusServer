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

tagview = function(db, dbMeta=db, minRunLen=3, keep=FALSE) {

    ## convert any paths to src_sqlite

    for (n in c("db", "dbMeta"))
        if (! inherits(get(n), "src_sqlite"))
            assign(n, src_sqlite(get(n)))

    ## copy needed tables from dbMeta to temporary db on same connection as db
    n = src_tbls(db)

    for (t in c("tags", "tagDeps", "recvDeps", "antDeps", "species", "projs")) {
        if (t %in% n)
            dbGetQuery(db$con, paste("drop table", t))
        copy_to(db, tbl(dbMeta,t) %>% collect, t, temporary=FALSE)
    }

    ## for now, ignore tag ambiguities

    query = "
CREATE VIEW allt AS SELECT
t1.*, t2.*, t3.*, t4.*, t5.*, t6.*, t7.*, t8.*, t9.*, t10.* FROM
hits AS t1
LEFT JOIN runs     AS t2  ON t1.runID      = t2.runID
LEFT JOIN batches  AS t3  ON t3.batchID    = t1.batchID
LEFT JOIN tags     AS t4  ON t4.tagID      = t2.motusTagID
LEFT JOIN tagDeps  AS t5  ON t5.tagID      = t2.motusTagID  AND
 t5.tsStart = (SELECT max(t5b.tsStart) FROM tagDeps  AS t5b WHERE t5b.tagID = t2.motusTagID AND t5b.tsStart <= t1.ts AND (t5b.tsEnd IS NULL OR t5b.tsEnd >= t1.ts))
LEFT JOIN recvDeps AS t6  ON t6.deviceID   = t3.motusDeviceID      AND
 t6.tsStart = (SELECT max(t6b.tsStart) FROM recvDeps AS t6b WHERE t6b.deviceID=t3.motusDeviceID      AND t6b.tsStart <= t1.ts AND (t6b.tsEnd IS NULL OR t6b.tsEnd >= t1.ts))
LEFT JOIN antDeps  AS t7  ON t7.deployID   = t6.deployID    AND t7.port = t2.ant
LEFT JOIN species  AS t8  ON t8.id         = t5.speciesID
LEFT JOIN projs    AS t9  ON t9.ID         = t5.projectID
LEFT JOIN projs    AS t10 ON t10.ID        = t6.projectID
"
    dbGetQuery(db$con, "DROP VIEW IF EXISTS allt")
    dbGetQuery(db$con, query)
    return(tbl(db, "allt"))





    ## ## get list of distinct tagIDs, including negative ones representing tag ambiguities

    ## tagIDs = tbl(db, "runs") %>% select(motusTagID) %>% distinct_ %>% collect

    ## ## real tag IDs are positive; negative IDs are tag ambiguities which we must lookup

    ## realTagIDs = tagIDs %>% subset(motusTagID > 0)

    ## ambigIDs = tagIDs %>% subset(motusTagID < 0)

    ## if (isTRUE(nrow(ambigIDs) > 0)) {
    ##     ambig = tbl(db, "tagAmbig")
    ##     ambigTagIDs = ambigIDs %>% left_join (ambig, by=c("motusTagID" = "ambigID")) %>%
    ##         select(motusTagID1, motusTagID2, motusTagID3, motusTagID4, motusTagID5, motusTagID6) %>%
    ##         collect %>% unlist %>% c %>% unique
    ##     realTagIDs = c(realTagIDs, ambigTagIDs)
    ## }

    ## ## realTagIDs now contains a full set of positive motusIDs for all tags (possibly)
    ## ## detected.

    ## ## get the deployments for these tags

    ## ## get list of tag ambiguities
    ## ambig = tagIDs %>% filter( motusTagID < 0)
    ## haveAmbig = nrow(ambig) > 0


    ## if (! haveAmbig) {
    ##     ## create temporary copies of any subset tables we need
    ##     if (dbT != db) {

    ##     t = tbl(db, "hits") %>%   ## detections
    ##         left_join (tbl(db, "runs"), by=c(runID="runID")) %>%    ## linked to their runs of detections
    ##         filter_ (~len >= minRunLen) %>%

    ##         left_join (tbl(dbT,"tags") %>% select_("tagID", "mfgID", "speciesID","projectID", "nomFreq", "period"), by=c(motusTagID="tagID"), copy=TRUE) %>% ## linked to their tag metadata
    ##         left_join (tbl(dbS, "species"), by=c(speciesID="id"), copy=TRUE) %>%  ## linked to the species code
    ##         left_join (tbl(dbP, "projects"), by=c(projectID="id"), copy=TRUE) %>% ## linked to the project code
    ##     mutate_ (fullID = ~printf("%s#%s@%g:%.1f", projCode, mfgID, nomFreq, period)) ## can't seem to do this in dplyr-style; note that printf is in SQLITE
    ##     return(t)
    ##     }
    ## } else {
    ##     ## each combination of (ambigID, batchID) represents a single group of ambiguous tags
    ##     ## We generate a new
    ##     ## get list of those motus Tag IDs involved in ambiguities (might overlap with previous list)
    ##     ambigTagIDs = tagIDs %>% bind_rows(tbl(db, "batchAmbig") %>% select (motusTagID) %>% collect)
    ## }
}
