#' find tags in a Lotek receiver dataset
#'
#' This function searches for sequences of tag detections
#' corresponding to registered (ID, burst interval) pairs and adds
#' them to the hits, runs, batches etc. tables in the receiver
#' database.
#'
#' @param serno receiver serial number
#'
#' @param src dplyr src_sqlite to (lotek) receiver database
#'
#' @param tagDB path to sqlite tag registration database
#'
#' @param par list of parameters to the filtertags code.  Defaults
#' to \link{\code{ltDefaultFindTagsParams}}
#'
#' @return the number of tag detections in the stream.
#'
#' @note FIXME: we run all data from the receiver in a single go; we need
#' a batch concept for these receivers, if for no other reason than
#' to allow time/deployment-dependent parameter overrides.
#' see \link{https://github.com/jbrzusto/motusServer/issues/60}
#' For now, any project or receiver parameter override active
#' at the time the function is called will be used.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ltFindTags = function(serno, src, tagDB, par = ltDefaultFindTagsParams) {

    ## FIXME: this should be the path to the executable provided with
    ## the motus package
    cmd = "LD_LIBRARY_PATH=/usr/local/lib/boost_1.60 /home/john/proj/find_tags/find_tags_motus"
    if (is.list(par))
        pars = paste0("--", names(par), '=', as.character(par), collapse=" ")
    else
        pars = paste(par, collapse=" ")

    ## add the Lotek flag, so tag finder knows input is already in
    ## form of ID'd burst detections

    ## get parameter overrides
    por = getParamOverrides(serno, tsStart=Sys.time())

    bcmd = paste(cmd, pars, por, "--lotek", "--src_sqlite", tagDB, src$path, " 2>&1 ")
    cat("  => ", bcmd, "\n")

    ## run the tag finder
    tryCatch({
        cat(safeSys(bcmd, quote=FALSE))
    }, error = function(e) {
        motusLog("ltFindTags failed with %s", paste(as.character(e), collapse="   \n"))
    })

    ## get ID and stats for new batch of tag detections
    rv = dbGetQuery(src$con, "select batchID, numHits from batches order by batchID desc limit 1")

    return (c(rv))
}
