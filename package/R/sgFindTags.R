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
#' @param resume if TRUE, tag detection resumes where it last left
#'     off.  Typically, a new batch of data files arrives and is added
#'     to the receiver database using \code{sgMergeFiles()}, and then
#'     \code{sgFindTags} is called again to continue processing these
#'     new data.  FIXME: resume not yet implemented.
#' 
#' @param par list of parameters to the findtags code.
#' 
#' @param mbn integer monotonic boot number(s); this is the monoBN field
#'     from the \code{files} table in the receiver's sqlite database.
#'     Defaults to NULL, meaning process GPS fixes for all streams.
#'
#' @return the batch number and the number of tag detections in the stream.
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgFindTags = function(src, tagDB, resume=TRUE, par = "", mbn = NULL) {

    cmd = "/home/john/proj/find_tags/find_tags_motus"
    if (is.list(par))
        pars = paste0("--", names(par), '=', as.character(par), collapse=" ")
    else
        pars = paste(par)


    ## create a FIFO
    fifoName = tempfile("fifo")

    saveTZ = Sys.getenv("TZ")
    Sys.setenv(TZ="GMT")
    tStart = as.numeric(Sys.time())
    Sys.setenv(TZ=saveTZ)

    if (is.null(mbn))
        mbn = dbGetQuery(src$con, "select distinct monoBN from files order by monoBN") [[1]]

    ## create the fifo
    system(paste("mkfifo", fifoName))

    ## enable write-ahead-log mode so we can be reading from files table
    ## while tag finder writes to other tables
    
    dbGetQuery(src$con, "pragma journal_mode=wal")

    for (bn in sort(mbn)) {

        ## if not resuming, discard resume information.
        if (! resume)
            dbGetQuery(src$con, "delete from batchState")

        ## start the child
        bcmd = paste(cmd, pars, "--resume", paste0("--bootnum=", bn), tagDB, src$path, fifoName, " > /tmp/errors.txt 2>&1")

        ## start the tag finder
        p = pipe(bcmd, "rb") ## system(cmd, wait=FALSE)

        ## open a writer connection to the fifo, so
        ## repeated open/close by the sqlite query
        ## doesn't cause EOF on the reader side
        fout = file(fifoName, "wb")

        ## send each file in this boot session to the child
        sgStreamToFile(src, fifoName, bn)

        ## done, so close remaining writer so child can
        ## see EOF
        close(fout)

        ## wait for child to exit; its last act is to write "Done." to std::cout
        x = readLines(p, 1)
        close(p)

        ## do any needed timestamp fixups
        sgFixupTimestamps(src)
    }

    file.remove(fifoName)

    ## revert to journal mode delete, so we keep everything in a single file

    dbGetQuery(src$con, "pragma journal_mode=delete")

    ## get ID and stats for new batch of tag detections
    rv = dbGetQuery(src$con, "select batchID, numHits from batches order by batchID desc limit 1")

    return (c(rv))
}
