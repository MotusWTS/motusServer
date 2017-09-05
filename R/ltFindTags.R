#' find tags in a Lotek receiver dataset
#'
#' This function searches for sequences of tag detections
#' corresponding to registered (ID, burst interval) pairs and adds
#' them to the hits, runs, batches etc. tables in the receiver
#' database.
#'
#' @details the tag finder is run once for each boot session that
#' has at least one detection record.  Boot session numbers
#' are first generated from all the boottime records.
#'
#' @param src dplyr src_sqlite to (lotek) receiver database
#'
#' @param tagDB path to sqlite tag registration database
#'
#' @param par list of parameters to the filtertags code.  Defaults
#' to NULL;
#'
#' @return a data.frame with these columns:
#' \itemize{
#'   \item batchID the batch number
#'   \item numHits the number of unfiltered tag detections in the stream.
#' }
#' and one row per boot session with detection records in the .DTA file
#' (though not necessarily any detections from this package's tag finder).
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ltFindTags = function(src, tagDB, par = NULL) {

    ## generate relative boot numbers, given the boot times
    DTAboot = dbGetQuery(src$con, "select * from DTAboot order by ts")
    DTAboot$relboot = seq(along=DTAboot$relboot)
    dbExecute(src$con, "delete from DTAboot")
    dbWriteTable(src$con, "DTAboot", DTAboot, append=TRUE, row.names=FALSE)

    ## FIXME: this should be the path to the executable provided with
    ## the motus package
    cmd = "LD_LIBRARY_PATH=/usr/local/lib/boost_1.60 /sgm/bin/find_tags_motus"
    if (is.list(par))
        pars = paste0("--", names(par), '=', as.character(par), collapse=" ")
    else
        pars = paste(par, collapse=" ")

    pars = paste0(pars, " --external_param=metadata_hash=", getMetadataHash(), " --lotek --src_sqlite ")

    ## lookup each boottime in the DTAtags table, so we can tell which
    ## boot sessions actually have records

    btrec = dbGetQuery(src$con, "select t1.relboot, (select ts from DTAtags as t2 where t2.ts >= t1.ts order by t2.ts limit 1) as mints from DTAboot as t1")

    ## boot numbers to use are those where there's a time difference between
    ## first records at or after the boot timestamps; assume the last boot session
    ## has some data.
    bn = btrec$relboot[c(diff(btrec$mints)>0, TRUE)]

    ## drop the last bootnum if there are no DTAtags records after it.
    if (dbGetQuery(src$con, "select not exists (select * from DTAtags as t1 where ts > (select max(ts) from DTAboot))")[[1]] == 1)
        bn = head(bn, -1)

    for (bootnum in bn) {
        ## add the Lotek flag, so tag finder knows input is already in
        ## form of ID'd burst detections

        bcmd = paste(cmd, pars, "--bootnum", bootnum, tagDB, attr(src$con, "dbname"), " 2>&1 ")
        cat("  => ", bcmd, "\n")

        ## run the tag finder
        tryCatch({
            cat(safeSys(bcmd, quote=FALSE))
        }, error = function(e) {
            motusLog("ltFindTags failed with %s", paste(as.character(e), collapse="   \n"))
        })
    }
    ## get ID and stats for new batch of tag detections
    rv = dbGetQuery(src$con, paste0("select batchID, numHits from batches order by batchID desc limit ", length(bn)))

    return (rv)
}
