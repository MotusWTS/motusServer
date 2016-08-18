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
#' @param keepOld the maximum number of batches of output from previous
#' runs to keep in the database.  Oldest are deleted first.
#' If < 0, do note delete any previous runs.
#' 
#' @return the number of tag detections in the stream.
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ltFindTags = function(src, tagDB, par = NULL, toFile=NULL, keepOld=0) {

    deleteOldFindTags(keepOld)
    
    ## FIXME: this should be the path to the executable provided with
    ## the motus package
    cmd = "LD_LIBRARY_PATH=/usr/local/lib/boost_1.60 /home/john/proj/find_tags/find_tags_motus"
    if (is.list(par))
        pars = paste0("--", names(par), '=', as.character(par), collapse=" ")
    else
        pars = paste(par, collapse=" ")

    ## add the Lotek flag, so tag finder knows input is already in
    ## form of ID'd burst detections
    
    pars = paste(pars, "--lotek")
    
    ## enable write-ahead-log mode so we can be reading from files table
    ## while tag finder writes to other tables
    
    dbGetQuery(src$con, "pragma journal_mode=wal")

    tags = tagDB %>% src_sqlite %>% tbl("tags")
    
    x = tbl(src, "DTAtags")
    xx = x %>% select (ts, id, ant, sig, antFreq, gain, codeSet, lat, lon) %>% arrange(ts) %>% filter (id != 999) %>% collect(n=Inf)
    if (nrow(xx) > 0) {
        if (! is.null(toFile)) {
            p = file(toFile, "w")
        } else {
            cmd = paste(cmd, pars, tagDB, src$path, " > /tmp/errors.txt 2>&1")
            cat("Doing ", cmd, "\n")
            p = pipe(cmd, "w", encoding="")
        }
        write.table(xx, p, sep=",", quote=FALSE, row.names=FALSE, col.names=FALSE, na="-999")
        close(p)
    }
    
    saveTZ = Sys.getenv("TZ")
    Sys.setenv(TZ="GMT")
    tStart = as.numeric(Sys.time())
    Sys.setenv(TZ=saveTZ)

    ## revert to journal mode delete, so we keep everything in a single file
    dbGetQuery(src$con, "pragma journal_mode=delete")

    ## get ID and stats for new batch of tag detections
    rv = dbGetQuery(src$con, "select batchID, numHits from batches order by batchID desc limit 1")

    return (c(rv))
}
