#' create an sqlite database of all detections of tags from a motus project and
#' the associated metadata for both tags and receivers
#'
#' @param projectID integer scalar motus project ID
#'
#' @param maxHits if not NULL, specifies a maximum number of tag hits returned;
#' only intended for testing
#'
#' @return returns a src_sqlite to the SQLite database
#' which will be called proj-NNN.motus and be in folder \code{MOTUS_PATH$TAG_PROJ}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

makeTagProjDB = function(projectID=83, maxHits=NULL) {

    ## open the transfer tables
    db = openMotusDB()
    con = db$con

    ## open the cached motus metadata DB
    mdb = safeSQL(getMotusMetaDB())

    ## get all motusTagIDs for that project
    mids = mdb("select tagID from tags where projectID = 83 and dateBin >= '2016' order by tagID")

    dbGetQuery(con, "create temporary table if not exists temp_tagIDs (tagID integer primary key)")
    dbWriteTable(con, "temp_tagIDs", mids, append=TRUE, row.names=FALSE)

    ## get all motusTagIDs which might be ambiguous with these tags
    ambig = db("select * from tagAmbig as t1 join temp_tagIDs as t2 where
t1.motusTagID1 = t2.tagID
or t1.motusTagID2 = t2.tagID
or t1.motusTagID3 = t2.tagID
or t1.motusTagID4 = t2.tagID
or t1.motusTagID5 = t2.tagID
or t1.motusTagID6 = t2.tagID")

    mids$tagID = c(mids$tagID, ambig$ambigID)

    ## get all runs involving these tags
    runs = db(sprintf("select * from runs where motusTagID in (%s)", paste(mids$tagID, collapse=",")))

    ## get all batches these runs come from
    bids = unique(c(runs$batchIDbegin, runs$batchIDend))
    batches = db(sprintf("select * from batches where batchID in (%s)", paste(bids, collapse=",")))

    ## fixup any errant motusDeviceIDs
    devListFix = list(
        ## (FROM, TO) pairs for motusDeviceID
        c(688, 524),   ## Lotek-224
        c(532, 501),   ## Lotek-6458
        c(530, 497)    ## Lotek-6352
    )

    for (i in seq(along=devListFix)) {
        bad = which(batches$motusDeviceID == devListFix[[i]][1])
        if (length(bad) > 0) {
            batches$motusDeviceID[bad] = devListFix[[i]][2]
        }
    }

    ## get all hits belonging to these runs
    ## the simple approach fails:
    ##     hits = db(sprintf("select * from hits where runID in (%s)", paste(runs$runID, collapse=",")))
    ## because the query text is much too large, we write the runIDs to a temporary
    ## table and do a join query.

    con = environment(db)$con

    dbGetQuery(con, "create temporary table temp_runIDs (runID integer primary key)")
    dbWriteTable(con, "temp_runIDs", runs[,c("runID"), drop = FALSE], append=TRUE, row.names=FALSE)

    if (is.null(maxHits))
        hits = dbGetQuery(con, "select t1.* from hits as t1 join temp_runIDs as t2 on t1.runID=t2.runID")
    else
        hits = dbGetQuery(con, paste0("select t1.* from hits as t1 join temp_runIDs as t2 on t1.runID=t2.runID limit ", maxHits ))

    ## get tag project database
    s = getTagProjSrc(projectID=83)

    dbWriteTable(s$con, "batches", batches[, grep("motusJobID", names(batches), invert=TRUE, value=TRUE)], append=TRUE, row.names=FALSE)
    dbWriteTable(s$con, "runs", runs, append=TRUE, row.names=FALSE)
    dbWriteTable(s$con, "hits", hits, append=TRUE, row.names=FALSE)

    return(s)
}
