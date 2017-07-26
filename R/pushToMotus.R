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
                                                 tsMotus     = 0) %>% as.data.frame
            ## write new tag ambiguities
            ## but work around bug in RMySQL
            dbWriteTable(mtcon, "temptagAmbig", newAmbig, overwrite=TRUE, row.names=FALSE)
            MotusDB("replace into tagAmbig select * from temptagAmbig")
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

    for (i in 1:nrow(newBatches)) {

        b = newBatches[i,]

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
                runs$batchIDbegin = runs$batchIDbegin + offsetBatchID
                dbWriteTable(mtcon, "runs", runs, append=TRUE, row.names=FALSE)
                ## rename batchIDbegin column so we can use it as batchID in batchRuns table
                names(runs)[grep("batchIDbegin", names(runs))] = "batchID"
                dbWriteTable(mtcon, "batchRuns", runs[, c("batchID", "runID")], append=TRUE, row.names=FALSE)
            }
            dbClearResult(res)
        }

        ## ----------  update existing runs that overlap this batch  ----------

        ## For runs which began before this batch and which were processed
        ## during this batch, update their length and tsEnd fields

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
            runUpd$batchIDbegin = runUpd$batchIDbegin + runUpd$offsetBatchID  ## offsetBatchID depends on batchID via the join above
            dbInsertOrReplace(mtcon, "runs", runUpd[, c("runID", "batchIDbegin", "tsBegin", "tsEnd", "done", "motusTagID", "ant", "len")])

            ## add records to batchRuns table
            runUpd$batchID = b$batchID + offsetBatchID  ## current batch ID
            dbWriteTable(mtcon, "batchRuns", runUpd[, c("batchID", "runID")], append=TRUE, row.names=FALSE)
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

        if (nrow(bpa) > 0)
            dbWriteTable(mtcon, "batchParams", bpa, append=TRUE, row.names=FALSE)

        ## ----------  copy pulseCounts  ----------
        pcs = sql("select * from pulseCounts where batchID = %d", b$batchID)
        pcs$batchID = pcs$batchID + offsetBatchID

        if (nrow(pcs) > 0)
            dbWriteTable(mtcon, "pulseCounts", pcs, append=TRUE, row.names=FALSE)

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

    ## To indicate they are complete and ready for transfer, set
    ## tsMotus on these batches.

    MotusDB("update batches set tsMotus = 0 where tsMotus = -1 and batchID >= %d and batchID <= %d",
            offsetBatchID + newBatches$batchID[1],
            offsetBatchID + tail(newBatches$batchID, 1))

    invisible(NULL)
}
