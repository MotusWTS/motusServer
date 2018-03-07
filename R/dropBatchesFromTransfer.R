#' delete a set of batches and all related data from the master data base
#'
#' @param batchIDs integer vector of batch IDs
#'
#' @return integer vector of those batchIDs which were actually deleted.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

dropBatchesFromTransfer = function(batchIDs) {

    stop("must be re-implemented")

    bid = paste(batchIDs, collapse=",")
    tx = MotusDB("select batchID, status from batches where batchID in (%s)", bid)

    if (nrow(tx) == 0)
        return(integer(0))  ## no batches to delete after all

    ## alter the "runs" table to take into account deleted batches:
    ## runs have starting and ending batch numbers, but in general,
    ## the run doesn't span *all* batches in between those numbers,
    ## but only all batches *from that receiver and in between those
    ## numbers*.

    ## The safest way to modify the runs table seems to be:
    ## - determine all runIDs for hits belonging to the batches
    ##   to be deleted
    ## - for each runID, get the count of its hits by batchID
    ## - if there are no hits from non-deleting batchIDs, delete the run
    ## - otherwise, get the min and max non-deleting batchIDs for this
    ##   run, and the number of hits in non-deleting batches, and update
    ##   the run record.  However, if the original batchIDend and the one
    ##   calculated this way are different, batchIDend is set to 0, which
    ##   indicates a potentially unfinished run

    runIDs = MotusDB("select distinct runID from hits where batchID in (%s) order by runID", bid)[[1]]

    if (length(runIDs) > 0) {
        runBatchCount = MotusDB("select runID, batchID, count(*) as n from hits where runID in (%s) group by runID, batchID order by runID, batchID",
                                paste(runIDs, collapse=",")) %>% as.tbl

        ## a function to fix the entry for a single run from a
        fixup = function(x) {
            ## x is a set of rows from runBatchCount corresponding to one run
            del = x$batchID %in% batchIDs
            if (all(del)) {
                ## all batches this run intersects are being deleted, so drop run
                MotusDB("delete from runs where runID=%d", x$runID[1])
            } else {
                ## adjust this run to include only hits from batches not being deleted
                y = subset(x, ! del)
                MotusDB("update runs set batchIDbegin=%d, batchIDend=if(batchIDend=%d, batchIDend, 0), len=%d where runID=%d",
                        min(y$batchID),
                        max(y$batchID),
                        sum(y$n),
                        y$runID[1])
            }
        }

        ## do the fixup on each run
        runBatchCount %>% group_by(runID) %>% do(ignore=fixup(.))
    }

    ## tables which have a 1:1 link to batches via batchID are easier to deal with
    delTables = c("gps", "pulseCounts", "hits", "batchProgs", "batchParams", "batches")

    for (t in delTables)
        MotusDB("delete from %s where batchID in (%s)", t, bid)

    return (batchIDs)
}
