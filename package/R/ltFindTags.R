#' find tags in a Lotek receiver dataset
#'
#' This function searches for sequences of tag detections
#' corresponding to registered (ID, burst interval) pairs and adds
#' them to the hits, runs, batches etc. tables in the receiver
#' database.
#'
#' @param src dplyr src_sqlite to (lotek) receiver database
#'
#' @param tagDB path to sqlite tag registration database
#'
#' @param par list of parameters to the filtertags code.
#'
#' @param toFile if not NULL (the default), write lotek output lines
#' to the this file, rather than passing them to the tag finder.
#' No tag finding is performed in this case.
#' 
#' @return the number of tag detections in the stream.
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ltFindTags = function(src, tagDB, par = NULL, toFile=NULL) {

    cmd = "/home/john/proj/filter_tags/filter_tags_motus"
    if (is.list(par))
        pars = paste0("--", names(par), '=', as.character(par), collapse=" ")
    else
        pars = paste(par)

    ## enable write-ahead-log mode so we can be reading from files table
    ## while tag finder writes to other tables
    
    dbGetQuery(src$con, "pragma journal_mode=wal")

    ## For Lotek receivers, we need to run the tag finder separately for each codeset
    ## for which there are tags in the database, and detections in the receiver data.

    tags = tagDB %>% src_sqlite %>% tbl("tags")
    
    x = tbl(src, "DTAtags")
        xx = x %>% select (ts, id, ant, sig, antFreq, gain, codeSet) %>% arrange(ts) %>% filter (id != 999) %>% collect()
        if (nrow(xx) > 0) {
##            tmpTagDB = tempfile(fileext=".sqlite") %>% src_sqlite(TRUE)
            ## write the tag DB for this codeset to a new file
##            copy_to (tmpTagDB, tags %>% filter(codeset==cs) %>% select(tagID, mfgID, nomFreq, period) %>% collect, "tags", temporary=FALSE)
            if (! is.null(toFile)) {
                p = file(toFile, "w")
            } else {
                cmd = paste(cmd, pars, tagDB, src$path, " > /tmp/errors.txt 2>&1")
                cat("Doing ", cmd, "\n")
                p = pipe(cmd, "w", encoding="")
            }
            write.table(xx, p, sep=",", quote=FALSE, row.names=FALSE, col.names=FALSE)
            close(p)
            rm(tmpTagDB)
    }
    
    saveTZ = Sys.getenv("TZ")
    Sys.setenv(TZ="GMT")
    tStart = as.numeric(Sys.time())
    Sys.setenv(TZ=saveTZ)

    ## revert to journal mode delete, so we keep everything in a single file
    dbGetQuery(src$con, "pragma journal_mode=delete")

    ## get ID and stats for new batch of tag detections
    rv = dbGetQuery(src$con, "select ID, numRuns, numHits from batches order by ID desc limit 1")

    return (c(rv))
}
