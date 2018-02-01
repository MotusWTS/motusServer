#' delete one or more test batches from the master motus DB
#'
#' @details test batches are generated when a top-level job includes a
#' TRUE `isTesting` parameter.  This is used for debugging.
#'
#' Once such batches are in the master database, they will only be
#' returned by the dataServer for API `batches_for_*` calls that have
#' `includeTesting` set to TRUE, and only for admin users.
#'
#' Regardless, it will sometimes be useful to remove test batches from
#' the master DB.
#'
#' @param batchID integer vector of IDs of batches to be deleted; only those
#' which are marked in the DB as testing (i.e. whose `status` field is -1)
#' will be deleted.
#'
#' @return a logical vector of the same length as `batchID`, indicating which
#' batches were successfully deleted.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

deleteTestBatches = function(batchID) {

    batchID = as.integer(batchID)
    if (sum(! is.na(batchID)) == 0)
        return(logical(0))

    ## open the motus master DB (just in case)

    openMotusDB()

    ## find all batches satisfying the specifications

    bid = MotusDB("select batchID from batches where status=-1 and batchID in (%s)", SQL(paste(batchID, collapse=",")))[[1]]
    if (length(bid) > 0) {
        bids = SQL(paste(bid, collapse=","))

        ## tables to delete records from:
        MotusDB("delete from batches where batchID in (%s)", bids)
        MotusDB("delete from projBatch where batchID in (%s)", bids)
        MotusDB("delete from gps where batchID in (%s)", bids)
        MotusDB("drop table if exists _runs_from_test_batches")
        MotusDB("create temporary table _runs_from_test_batches as select runID from runs where batchIDbegin in (%s)", bids)
        MotusDB("drop index if exists _runs_from_test_batches_runID on _runs_from_test_batches")
        MotusDB("create index _runs_from_test_batches_runID on _runs_from_test_batches(runID)")

        ## runs which overlap but don't start in this batch will be deleted when
        ## the batch in which they start is deleted.  Runs should overlap either
        ## only test batches, or only non-test batches.  However due to a bug
        ## whereby the tag finder was resumed for a non-test batch from stated
        ## saved in a test batch (see https://github.com/jbrzusto/motusServer/issues/342)
        ## this has not always been the case, so we have to delete runs (and
        ## their hits) from *all* batches where they occur if they began in a test batch.

        MotusDB("delete t2 from _runs_from_test_batches as t1 join batchRuns as t2 on t1.runID=t2.runID")
        MotusDB("delete t2 from _runs_from_test_batches as t1 join hits as t2 on t1.runID=t2.runID")
        MotusDB("delete from runs where batchIDbegin in (%s)", bids)
        MotusDB("delete from batchProgs where batchID in (%s)", bids)
        MotusDB("delete from batchParams where batchID in (%s)", bids)
        MotusDB("delete from pulseCounts where batchID in (%s)", bids)
        MotusDB("delete from reprocessBatches where batchID in (%s)", bids)
        MotusDB("delete from reprocessBatches where batchID in (%s)", SQL(paste(- bid, collapse=","))) ## negated batchIDs might also be in reprocessBatches
    }
    ## return TRUE for any batchID that was a test batch

    ok = match(batchID, bid)
    return(! is.na(ok))
}
