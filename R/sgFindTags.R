#' find tags in an SG stream
#'
#' A stream is the ordered sequence of raw data files from a receiver
#' corresponding to a single boot session (period between restarts).
#' This function searches for patterns of pulses corresponding to
#' coded ID tags and adds them to the hits, runs, batches etc. tables
#' in the receiver database.  Each boot session is run as a separate
#' batch.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param tagDB path to sqlite tag registration database
#'
#' @param resume if TRUE, tag detection resumes where it last left off
#'     for each given item in \code{mbn}.  Typically, a new batch of
#'     data files arrives and is added to the receiver database using
#'     \code{sgMergeFiles()}, and then \code{sgFindTags} is called
#'     again to continue processing these new data.  When running
#'     archived data retroactively, it is better to set
#'     \code{resume=FALSE}, otherwise if bootnums are not monotonic,
#'     then tag event histories will be scrambled leading to searching
#'     for the wrong tags at the wrong times.  This has often been the
#'     case for Beaglebone White receivers, since they had no internal
#'     memory for storing the bootcount, and relied on writing it to
#'     the SD card; updating to a new SD card would typically reset
#'     the boot count.
#'
#' @param par list of parameters to the findtags code; defaults to
#' \code{\link{sgDefaultFindTagsParams}}
#'
#' @param mbn integer monotonic boot number(s); this is the monoBN field
#'     from the \code{files} table in the receiver's sqlite database.
#'     Defaults to NULL, meaning run the tag finder on all boot sessions.
#'
#' @return the batch number and the number of tag detections in the stream.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgFindTags = function(src, tagDB, resume=TRUE, par = sgDefaultFindTagsParams, mbn = NULL) {

    cmd = "LD_LIBRARY_PATH=/usr/local/lib/boost_1.60 /home/john/proj/find_tags/find_tags_motus"
    if (is.list(par))
        pars = paste0("--", names(par), '=', as.character(par), collapse=" ")
    else
        pars = paste(par, collapse=" ")

    sql = function(...) dbGetQuery(src$con, sprintf(...))

    if (is.null(mbn))
        mbn = sql("select distinct monoBN from files order by monoBN") [[1]]

    for (bn in sort(mbn)) {

        ## if not resuming, discard resume information.
        if (! resume)
            sql("delete from batchState where progName='find_tags_motus' and monoBN=%d", bn)

        ## start the child;
        bcmd = paste(cmd, pars, if (resume) "--resume", paste0("--bootnum=", bn), "--src_sqlite", tagDB, src$path, " 2>&1 ")

        cat("  => ", bcmd, "\n")

        ## run the tag finder
        tryCatch({
            cat(safeSys(bcmd, quote=FALSE))
        }, error = function(e) {
            motusLog("sgFindTags failed with %s", paste(as.character(e), collapse="   \n"))
        })
    }

    ## get ID and stats for new batch of tag detections
    rv = dbGetQuery(src$con, "select batchID, numHits from batches order by batchID desc limit 1")

    return (c(rv))
}
