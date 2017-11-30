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

    ## open the motus master DB (just in case)

    openMotusDB()

    ## find all batches satisfying the specifications

    bid = MotusDB("select batchID from batches where status=-1 and batchID in (%s)", paste(batchID, collapse=","))
    bids = paste(bid, collapse=",")

    ## tables to delete records from:
    MotusDB("delete from batches where batchID in (%s)", bids)
    MotusDB("delete from projBatch where batchID in (%s)", bids)
    MotusDB("delete from gps where batchID in (%s)", bids)
    MotusDB("delete from runs where batchIDbegin in (%s)", bids)

    ## runs which overlap but don't start in this batch will be deleted when
    ## the batch in which they start is deleted.  We assume that test batches
    ## arise only from rerunning a full boot session, in which case all runs
    ## will nest within that, validating this approach.

    MotusDB("delete from batchRuns where batchID in (%s)", bids)
    MotusDB("delete from hits where batchID in (%s)", bids)
    MotusDB("delete from batchProgs where batchID in (%s)", bids)
    MotusDB("delete from batchParams where batchID in (%s)", bids)
    MotusDB("delete from pulseCounts where batchID in (%s)", bids)
    MotusDB("delete from reprocessBatches where batchID in (%s)", bids)
    MotusDB("delete from reprocessBatches where batchID in (%s)", paste(collapse( - bid, collapse=","))) ## negated batchIDs might also be in reprocessBatches

    ## return TRUE for any batchID that was a test batch

    ok = match(batchID, bid)
    return(! is.na(ok))
}
