#' Push any new tag detections to the motus master database.
#'
#' For now, this pushes into the transfer tables in the MySQL "motus"
#' database on the local host, from where the Motus server pulls
#' data periodically.
#'
#' Any batch whose ID is not in the receiver's motusTX table is sent
#' to the transfer tables.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @return no return value
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

pushToMotus = function(src) {
    con = src$con
    sql = function(...) dbGetQuery(con, sprintf(...))

    ## get batches without a record in motusTX
    motusTX = tbl(src, "motusTX")
    batches = tbl(src, "batches")
    newBatches = batches %>%
        anti_join (motusTX, by="batchID") %>%
        arrange(batchID) %>%
        collect

    if (nrow(newBatches) == 0)
        return()

    deviceID = getMotusDeviceID(src)
    if(! isTRUE(deviceID > 0))
        stop("invalid motus device ID for receiver with DB at ", attr(src$con, "dbname"))

    ## Ensure the device ID has been set on all batches.
    ## It is a constant, and the only reason we do this
    ## is to have the same schema for receiver and master
    ## databases.
    sql("update batches set motusDeviceID=%d", deviceID)

    newBatches$motusDeviceID = deviceID

    ## open the motus transfer table

    mtcon = openMotusDB()$con ## also ensures global MotusDB exists

    ## Writing a record to the motus batches table indicates that
    ## batch is ready for transfer, so must be the last thing we do
    ## for a batch, after writing all hits, runs, etc.

    ## So we need to reserve a block of nrow(b) IDs in motus.batches

    firstMotusBatchID = motusReserveKeys("batches", nrow(newBatches))
    offsetBatchID = firstMotusBatchID - newBatches$batchID[1]

    ## ---------- transfer tag ambiguities ----------
    ## This is a two-way process, in that we want to have a unique
    ## master ambigID across receivers for each ambiguity of a
    ## particular set of (motus) tagIDs.

    ## 1. get tag ambiguities from this receiver which don't already have a master
    ## ambigID:

    ambig = tbl(src, "tagAmbig") %>% filter (is.null(masterAmbigID)) %>% collect

    if (nrow(ambig) > 0) {

        ## 2. join to the master ambiguity table by tagIDs
        masterAmbig = as.tbl(MotusDB("select * from tagAmbig"))

        joinAmbig = ambig %>% left_join (masterAmbig, by=c("motusTagID1", "motusTagID2", "motusTagID3", "motusTagID4", "motusTagID5", "motusTagID6")) %>% collect

        ## 3. create entries in the master tagAmbig table for any not
        ## already there

        newA = which(is.na(joinAmbig$ambigID.y))
        n = length(newA)
        if (n > 0) {
            ## note use of negative n to reserve negative, descending keys
            firstMasterAmbigID = motusReserveKeys("tagAmbig", -n)

            ## fill in new masterAmbigIDs
            joinAmbig$ambigID.y[newA] = seq(from = firstMasterAmbigID, by = -1, length = n)

            ## create table with new tag ambiguities to be added to master tagAmbig table
            newAmbig = joinAmbig[newA, ] %>% transmute_(
                                                 ambigID="ambigID.y",
                                                 motusTagID1 = "motusTagID1",
                                                 motusTagID2 = "motusTagID2",
                                                 motusTagID3 = "motusTagID3",
                                                 motusTagID4 = "motusTagID4",
                                                 motusTagID5 = "motusTagID5",
                                                 motusTagID6 = "motusTagID6",
                                                 ambigProjectID = 0,
                                                 tsMotus     = -1) %>% as.data.frame
            ## write new tag ambiguities
            ## but work around bug in RMySQL
            dbWriteTable(mtcon, "temptagAmbig", newAmbig, overwrite=TRUE, row.names=FALSE)
            MotusDB("
replace into
   tagAmbig (
      ambigID,
      motusTagID1,
      motusTagID2,
      motusTagID3,
      motusTagID4,
      motusTagID5,
      motusTagID6,
      ambigProjectID,
      tsMotus
   )
   select
      ambigID,
      motusTagID1,
      motusTagID2,
      motusTagID3,
      motusTagID4,
      motusTagID5,
      motusTagID6,
      ambigProjectID,
      tsMotus
   from
      temptagAmbig
")
            MotusDB("drop table temptagAmbig")
        }

        ## 4. record the masterAmbigID for each tag ambiguity in the receiver DB
        copy_to(src, joinAmbig, "joinAmbig")  ## add as a temporary table
        sql("replace into tagAmbig select `ambigID.x` as ambigID, `ambigID.y` as masterAmbigID, motusTagID1, motusTagID2, motusTagID3, motusTagID4, motusTagID5, motusTagID6 from joinAmbig")
    }

    ## ----------  copy batches ----------

    ## update the batchID fields for the batches, then insert them into motus.batches
    ## The default value of -1 for the tsMotus field means these records represent
    ## incomplete batches, not to be transferred to motus until the tsMotus field
    ## is set to zero at the end of this function.

    txBatches = newBatches
    txBatches$batchID = txBatches$batchID + offsetBatchID

    txBatches$tsMotus = -1

    dbWriteTable(mtcon, "batches", txBatches %>% as.data.frame, append=TRUE, row.names=FALSE)

    ## set bogus offsets, in case no record of these types; permits update to
    ## motusTX table in sqlite database to work.

    offsetRunID = 0
    offsetHitID = 0

    ## number of rows to move at a time
    CHUNK_ROWS = 50000

    ## for each batch, transfer associated records

    for (i in seq_len(nrow(newBatches))) {

        b = newBatches[i,]
        txBatchID = txBatches$batchID[i]

        ## accumulate unique tag project IDs:
        tagDepProjIDs = c()

        ## ----------  copy new runs  ----------

        ## get count of new runs and 1st run ID for this batch
        runInfo = sql("select count(*), min(runID) from runs where batchIDbegin = %d", b$batchID)

        if (runInfo[1,1] > 0) {

            ## reserve the required number of runIDs
            firstMotusRunID = motusReserveKeys("runs", runInfo[1,1])
            offsetRunID = firstMotusRunID - runInfo[1,2]

            res = dbSendQuery(con, sprintf("select * from runs where batchIDBegin = %d order by runID", b$batchID))
            dbClearResult(res)

            ## grab runs from this batch, substituting any ambiguous tag IDs with their master (global) version:
            res = dbSendQuery(con, sprintf("
select
   runID,
   batchIDbegin,
   tsBegin,
   tsEnd,
   done,
   ifnull(t2.masterAmbigID, t1.motusTagID) as motusTagID,
   ant,
   len
from
   runs as t1
   left join tagAmbig as t2 on t1.motusTagID=t2.ambigID
where
   t1.batchIDbegin = %d
order by
   t1.runID
", b$batchID))

            repeat {
                runs = dbFetch(res, CHUNK_ROWS)
                if (nrow(runs) == 0)
                    break
                runs$runID        = runs$runID        + offsetRunID
                runs$batchIDbegin = txBatchID
                dbWriteTable(mtcon, "runs", runs, append=TRUE, row.names=FALSE)

                ## Set the tagDepProjectID for each run; it will be
                ## the project ID of the latest deployment of that tag
                ## that which begins no later than the start of the
                ## run.  We allow for tsEnd of a tagDep to be null or
                ## 0, meaning "still active".  And we allow a slop of
                ## 20 minutes in the deployment time, to catch runs which
                ## started slightly before the nominal deployment time
                ## (see https://github.com/jbrzusto/find_tags/issues/41 )

                MotusDB("
update
   runs as t1
set
   t1.tagDepProjectID = (
      select
         t2.projectID
      from
         tagDeps as t2
      where
         t2.motusTagID=t1.motusTagID
         and t2.tsStart - 1200 <= t1.tsBegin
      order by
         t2.tsStart desc
      limit 1)
where
   t1.runID between %d and %d
",
runs$runID[1], tail(runs$runID, 1))

            ## append these runs to the batchRuns table
                MotusDB("
insert
   into batchRuns (
      select
         batchIDbegin as batchID,
         runID,
         tagDepProjectID
      from
         runs
      where
         runID between %d and %d
   )
",
runs$runID[1], tail(runs$runID, 1))

            }
            dbClearResult(res)
        }

        ## ----------  update existing runs that overlap this batch  ----------

        ## For runs which began before this batch and which were processed
        ## during this batch, update their length, tsEnd, and done fields

        res = dbSendQuery(con, sprintf("
select
   *
from
   batchRuns as t0
   join runs as t1 on t1.runID=t0.runID and t1.batchIDbegin <> t0.batchID
   join motusTX as t2 on t2.batchID=t1.batchIDbegin
where
   t0.batchID = %d
order by t1.runID
", b$batchID))
        repeat {
            runUpd = dbFetch(res, CHUNK_ROWS)
            if (nrow(runUpd) == 0)
                break

            runUpd$runID        = runUpd$runID        + runUpd$offsetRunID    ## offsetRunID depends on batchID via the join above

            ## create a temporary table from which to update using an update with join
            MotusDB("
create temporary table if not exists
   tempRunUpdates (
      runID bigint(20) primary key,
      tsEnd double,
      len int(11),
      done tinyint(4)
   )
")
            MotusDB("truncate table tempRunUpdates")

            ## add updated portions of records to the temporary table)
            dbWriteTable(mtcon, "tempRunUpdates", runUpd[, c("runID", "tsEnd", "len", "done")], append=TRUE, row.names=FALSE)

            ## update the runs table via a join with tempRunUpdates
            MotusDB("
update
   tempRunUpdates as t1
   join runs as t2 on t2.runID = t1.runID
set
   t2.tsEnd = t1.tsEnd,
   t2.len   = t1.len,
   t2.done  = t1.done
")

            ## add records to batchRuns table; unlike the case of new runs, the runIDs for this
            ## set are not necessarily consecutive, so we have to explicitly supply them.
            MotusDB("
insert
   into batchRuns (
      select
         %d as batchID,
         runID,
         tagDepProjectID
      from
         runs
      where
         runID in (%s)
   )
",
txBatchID, paste(runUpd$runID, collapse=","))
        }
        dbClearResult(res)


        ## ----------  copy hits  ----------

        ## get count of hits and 1st hit ID for this batch
        hitInfo = sql("select count(*), min(hitID) from hits where batchID = %d", b$batchID)
        if (hitInfo[1,1] > 0) {
            ## reserve the required number of hitIDs
            firstMotusHitID = motusReserveKeys("hits", hitInfo[1,1])
            offsetHitID = firstMotusHitID - hitInfo[1,2]

            res = dbSendQuery(con, sprintf("select * from hits where batchID = %d order by hitID", b$batchID))

            repeat {
                hits = dbFetch(res, CHUNK_ROWS)
                if (nrow(hits) == 0)
                    break
                hits$hitID   = hits$hitID   + offsetHitID
                hits$runID   = hits$runID   + offsetRunID
                hits$batchID = hits$batchID + offsetBatchID
                dbWriteTable(mtcon, "hits", hits, append=TRUE, row.names=FALSE)

                ## copy the helper field tagDepProjectID from the value for the associated run
                MotusDB("
update
   hits as t1
join
   runs as t2 on t2.runID=t1.runID
set
   t1.tagDepProjectID = t2.tagDepProjectID
where
   t1.hitID between %.0f and %.0f
", hits$hitID[1], tail(hits$hitID, 1))
            }
            dbClearResult(res)
        }
        ## ----------  copy gps  ----------

        gps = sql("select * from gps where batchID = %d order by ts", b$batchID)
        gps$batchID = gps$batchID + offsetBatchID
        dbWriteTable(mtcon, "gps", gps, append=TRUE, row.names=FALSE)

        ## ----------  copy batchProgs  ----------
        bpr = sql("select * from batchProgs where batchID = %d", b$batchID)
        bpr$batchID = bpr$batchID + offsetBatchID

        if (nrow(bpr) > 0)
            dbWriteTable(mtcon, "batchProgs", bpr, append=TRUE, row.names=FALSE)


        ## ----------  copy batchParams  ----------
        bpa = sql("select * from batchParams where batchID = %d", b$batchID)
        bpa$batchID = bpa$batchID + offsetBatchID
        bpa$paramVal = as.character(bpa$paramVal)
        if (nrow(bpa) > 0)
            dbWriteTable(mtcon, "batchParams", bpa, append=TRUE, row.names=FALSE)

        ## ----------  copy pulseCounts  ----------
        pcs = sql("select * from pulseCounts where batchID = %d", b$batchID)
        pcs$batchID = pcs$batchID + offsetBatchID

        if (nrow(pcs) > 0)
            dbWriteTable(mtcon, "pulseCounts", pcs, append=TRUE, row.names=FALSE)

        ## --------- update projBatch helper table -----

        ## Note: we do this as a nested query so that the inner one
        ## can take advantage of a covering index on the batchRuns
        ## table.  i.e. if instead we used the flat query `select %d
        ## as batchID, distinct (tagDepProjectID) from batchRuns where
        ## batchID=%d` then mariadb, apparently not smart enough to
        ## grab the distinct values of tagDepProjectID from the index,
        ## would instead scan a portion of the batchRuns table, which
        ## can be very large (e.g. 6.9M runs for batch 68902)

        MotusDB("
insert
   into projBatch (
      select
         tagDepProjectID,
         %d as batchID
      from
         (
            select
               distinct tagDepProjectID
            from
               batchRuns
            where
               batchID = %d
               and tagDepProjectID is not null
         ) as t
   )
", txBatchID, txBatchID)
        ## Mark what has been transferred

        sql("insert into motusTX (batchID, tsMotus, offsetBatchID, offsetRunID, offsetHitID) \
                         values  (  %d   , %.4f   , %d           , %.0f       , %.0f       )",
            b$batchID,
            as.numeric(Sys.time()),
            offsetBatchID,
            offsetRunID,
            offsetHitID
            )
    }

    ## Set the recvDepProjectID for each batch; it will be the project
    ## ID of the latest deployment of that receiver which overlaps the
    ## batch.  We allow for tsEnd of a recvDep to be null or 0, meaning
    ## "still active".

    MotusDB("update batches as t1 set t1.recvDepProjectID = (select t2.projectID from recvDeps as t2 where t2.deviceID=t1.motusDeviceID and t2.tsStart <= t1.tsEnd and (t2.tsEnd is null or t2.tsEnd = 0 or t1.tsStart <= t2.tsEnd) order by t2.tsStart desc limit 1) where t1.batchID between %d and %d",
            txBatches$batchID[1],
            tail(txBatches$batchID, 1))

    ## To indicate they are complete and ready for transfer, set
    ## tsMotus on these batches.

    MotusDB("update batches set tsMotus = 0 where tsMotus = -1 and batchID between %d and %d",
            txBatches$batchID[1],
            tail(txBatches$batchID, 1))

    invisible(NULL)
}
