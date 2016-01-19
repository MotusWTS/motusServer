#' find tags in an SG stream
#'
#' A stream is the ordered sequence of raw data files from a receiver
#' corresponding to a single boot session (period between restarts).
#' This function searches for patterns of pulses corresponding to
#' coded ID tags and adds them to the hits, runs, batches etc. tables
#' in the receiver database.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param tagDB path to sqlite tag registration database
#'
#' @param par list of parameters to the findtags code.
#' 
#' @param mbn integer monotonic boot number(s); this is the monoBN field
#'     from the \code{files} table in the receiver's sqlite database.
#'     Defaults to NULL, meaning process GPS fixes for all streams.
#'
#' @return the number of tag detections in the stream.
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgFindTags = function(src, tagDB, par = NULL, mbn = NULL) {
    ## create user context
    u = new.env(emptyenv())

    cmd = "/home/john/proj/find_tags/find_tags_motus"
    if (is.list(par))
        pars = paste0("--", names(par), '=', as.character(par), collapse=" ")
    else
        pars = paste(par)

    ## enable write-ahead-log mode so we can be reading from files table
    ## while tag finder writes to other tables
    
    dbGetQuery(src$con, "pragma journal_mode=wal")

    cmd = paste(cmd, pars, tagDB, src$path, " > /tmp/errors.txt 2>&1")
    u$p = pipe(cmd, "wb", encoding="")

    ## cat("Doing ", cmd, "\n")
    
    ## Sys.sleep(15)
    
    saveTZ = Sys.getenv("TZ")
    Sys.setenv(TZ="GMT")
    tStart = as.numeric(Sys.time())
    Sys.setenv(TZ=saveTZ)

    ## don't write a NEWBN command at the start of the first batch
    u$notFirst = FALSE
    
    ## run the worker on the stream(s)
    g = sgRunStream(src,
                    function(bn, ts, cno, ct, u) {
                        if (cno > 0) {
                            ## FIXME?: why does calling writeChar( '', ...) fail (i.e. empty string) 
                            if (any(nchar(ct) > 0)) {
                                writeChar(ct, u$p, useBytes=TRUE, eos=NULL)
                            }
                        } else if (cno < 0) {
                            if (u$notFirst)
                                writeChar(paste0("\n!NEWBN,", bn, "\n"), u$p, useBytes=TRUE, eos=NULL)
                            u$notFirst = TRUE
                        }
                    },
                    mbn,
                    u)
    close(u$p)

    ## revert to journal mode delete, so we keep everything in a single file
    dbGetQuery(src$con, "pragma journal_mode=delete")

    ## get ID and stats for new batch of tag detections
    rv = dbGetQuery(src$con, "select ID, numRuns, numHits from batches order by ID desc limit 1")

    return (c(rv))
}
