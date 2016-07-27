#' Push any new tag detections to the motus master database.
#'
#' For now, this pushes into the transfer tables in the MySQL "motus"
#' database on discovery.acadiau.ca, from where the Motus server pulls
#' data periodically.  If this batch is a re-run, an entry is added
#' to the batchDelete table to indicate we're replacing the previous version.
#'
#' Any batch whose ID is not in the receiver's motusTX table is sent
#' to the transfer tables.  For these batches, if the monoBN is the
#' same as that for an existing batch, a record to delete the existing
#' batch is added to the batchDelete motus transfer table, and the batchID
#' in the receiver's motusTX table is negated, so that subsequent re-runs
#' don't try to delete it from motus again.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @return the batch number and the number of tag detections in the stream.
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

    ## find which existing batches are being superseded by new ones,
    ## based on them having the same monoBN field

    toDelete = motusTX %>% left_join (batches, by="batchID") %>%
        left_join (newBatches, by="monoBN", copy=TRUE) %>% collect

    deviceID = getMotusDeviceID(src)

    ## ensure the device ID has been set on all batches
    ## it is a constant, and the only reason we do this
    ## is to have the same schema for receiver and master
    ## databases.
    sql("update batches set motusDeviceID=%d", deviceID)

    batches$motusDeviceID = deviceID

    ## open the motus transfer table

    mt = openMotusDB()
    mtcon = mt$con
    mtsql = function(...) dbGetQuery(mtcon, sprintf(...))

    ## Writing a record to the motus batches table indicates that
    ## batch is ready for transfer, so must be the last thing we do
    ## for a batch, after writing all hits, runs, etc.

    ## So we need to reserve a block of nrow(b) IDs in motus.batches


    firstMotusBatchID = motusReserveKeys(mt, "batches", "batchID", nrow(newBatches), "motusDeviceID", -deviceID)
    offsetBatchID = firstMotusBatchID - newBatches$batchID[1]

    ## Transfer tag ambiguities.  This is a two-way process, in that we want to have
    ## a unique master ambigID across receivers for each ambiguity of a particular
    ## set of (motus) tagIDs.

    ## 1. get tag ambiguities from this receiver which don't already have a master
    ## ambigID:

    ambig = tbl(src, "tagAmbig") %>% filter (is.null(masterAmbigID)) %>% collect

    if (nrow(ambig) > 0) {

        ## 2. join to the master ambiguity table by tagIDs
        masterAmbig = tbl(mt, "tagAmbig") %>% collect

        joinAmbig = ambig %>% left_join (masterAmbig, by=c("motusTagID1", "motusTagID2", "motusTagID3", "motusTagID4", "motusTagID5", "motusTagID6")) %>% collect

        ## 3. create entries in the master tagAmbig table for any not
        ## already there

        newA = which(is.na(joinAmbig$ambigID.y))
        n = length(newA)
        if (n > 0) {
            ## note use of negative n to reserve negative, descending keys
            firstMasterAmbigID = motusReserveKeys(mt, "tagAmbig", "ambigID", -n, "motusTagID1", -deviceID)

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
            dbGetQuery(mtcon, "replace into tagAmbig select * from temptagAmbig")
            dbGetQuery(mtcon, "drop table temptagAmbig")
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
    dbInsertOrReplace(mtcon, "batches", txBatches %>% as.data.frame)

    ## set bogus offsets, in case no record of these types; permits update to
    ## motusTX table in sqlite database to work.

    offsetRunID = 0
    offsetHitID = 0

    ## number of rows to move at a time
    CHUNK_ROWS = 50000

    ## for each batch, transfer associated records

    for (i in 1:nrow(newBatches)) {

        b = newBatches[i,]

        ## ----------  copy runs  ----------

        ## get count of runs and 1st run ID for this batch
        runInfo = sql("select count(*), min(runID) from runs where batchIDbegin = %d", b$batchID)

        if (runInfo[1,1] > 0) {

            ## reserve the required number of runIDs
            firstMotusRunID = motusReserveKeys(mt, "runs", "runID", runInfo[1,1], "batchIDbegin", -deviceID)
            offsetRunID = firstMotusRunID - runInfo[1,2]

            res = dbSendQuery(con, sprintf("select * from runs where batchIDBegin = %d order by runID", b$batchID))
            repeat {
                runs = dbFetch(res, CHUNK_ROWS)
                if (nrow(runs) == 0)
                    break
                runs$runID        = runs$runID        + offsetRunID
                runs$batchIDbegin = runs$batchIDbegin + offsetBatchID
                runs$batchIDend   = runs$batchIDend   + offsetBatchID  ## correct even if batchIDend is NA
                dbInsertOrReplace(mtcon, "runs", runs)
            }
            dbClearResult(res)

            ## ----------  copy hits  ----------

            ## get count of hits and 1st hit ID for this batch
            hitInfo = sql("select count(*), min(hitID) from hits where batchID = %d", b$batchID)

            ## reserve the required number of hitIDs
            firstMotusHitID = motusReserveKeys(mt, "hits", "hitID", hitInfo[1,1], "batchID", -deviceID)
            offsetHitID = firstMotusHitID - hitInfo[1,2]

            res = dbSendQuery(con, sprintf("select * from hits where batchID = %d order by hitID", b$batchID))

            repeat {
                hits = dbFetch(res, CHUNK_ROWS)
                if (nrow(hits) == 0)
                    break
                hits$hitID   = hits$hitID   + offsetHitID
                hits$runID   = hits$runID   + offsetRunID
                hits$batchID = hits$batchID + offsetBatchID
                dbInsertOrReplace(mtcon, "hits", hits)
            }
            dbClearResult(res)
        }
        ## ----------  copy gps  ----------

        gps = sql("select * from gps where batchID = %d order by ts", b$batchID)
        gps$batchID = gps$batchID + offsetBatchID
        dbInsertOrReplace(mtcon, "gps", gps)

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

        ## ----------  generate runUpdates  ----------

        ## For runs which began before this batch and which either
        ## haven't ended or ended in this batch, update their length
        ## and batchIDend fields.

        res = dbSendQuery(con, sprintf("select * from runs as t1 left join motusTX as t2 on t1.batchIDbegin=t2.batchID where t1.batchIDBegin < %d and (t1.batchIDend is null or t1.batchIDend = %d) order by runID",
                                       b$batchID, b$batchID))
        repeat {
            runUpd = dbFetch(res, CHUNK_ROWS)
            if (nrow(runUpd) == 0)
                break

            runUpd$runID        = runUpd$runID        + runUpd$offsetRunID  ## offsetRunID depends on batchID via the join above
            runUpd$batchID      = b$batchID + offsetBatchID  ## this is just the current batchID, so we want the current offset
            runUpd$batchIDend   = runUpd$batchIDend + runUpd$offsetBatchID  ## offsetBatchID depends on batchID via the join above
            dbInsertOrReplace(mtcon, "runUpdates", runUpd[,c("batchID", "runID", "len", "batchIDend")])
        }
        dbClearResult(res)

        ## Mark what has been transferred

        sql("insert into motusTX (batchID, tsMotus, offsetBatchID, offsetRunID, offsetHitID) \
                         values  (  %d   , %.4f     , %d          , %g         , %g         )",
            b$batchID,
            as.numeric(Sys.time()),
            offsetBatchID,
            offsetRunID,
            offsetHitID
            )
    }

    ## To indicate they are complete and ready for transfer, set
    ## tsMotus on these batches.

    mtsql("update batches set tsMotus = 0 where tsMotus = -1 and batchID >= %d and batchID <= %d",
          offsetBatchID + newBatches$batchID[1],
          offsetBatchID + tail(newBatches$batchID, 1))

    ## For any batches being supersedes, add a record to batchDelete in the motus tables,
    ## and negate the batchID in the receiver motusTX table

    for (i in seq(along = toDelete$batchID.x)) {
        ## get ID of batch in master table
        bid = toDelete$batchID.x[i] + toDelete$offsetBatchID[i]

        mtsql("insert into batchDelete (batchIDbegin, batchIDend, ts, reason, tsMotus) values (%d, %d, %f, 're-ran site', 0))",
              bid, bid, as.numeric(Sys.time()))
        sql("update motusTX set batchID=-batchID where batchID=%d", toDelete$batchID.x[i])
    }
    dbDisconnect(mtcon)
}
