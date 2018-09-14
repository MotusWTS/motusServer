#' Pull any new or modified tag deployment records from motus
#'
#' This locks the metadata DB before querying motus for any changes to tag
#' deployment metadata since the 'mtime' record in the 'meta' table
#' of that DB.
#'
#' @return TRUE if any tag metadata were updated; FALSE otherwise
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

updateTagDeployments = function() {
    lockSymbol(MOTUS_METADB_CACHE)
    ## make sure we unlock the meta DB when this function exits, even on error
    on.exit(lockSymbol(MOTUS_METADB_CACHE, lock=FALSE))

    ## grab the time the tag deployment metadata DB was last updated.
    ## note the cast to real via '0+' in the following query
    ts = MetaDB("select 0+val from meta where key='tsTagDepsLastModified'")[[1]]
    if (length(ts) == 0) {
        ts = as.numeric(file.info(MOTUS_METADB_CACHE)$mtime)
        MetaDB("insert into meta values ('tsTagDepsLastModified', %f)", ts)
    }
    ## grab any tag deployment changes since we last updated
    ## (note the 300 second slop in case server clocks are out of sync)
    t = motusSearchTags(tsLastModified = ts - 300)
    if (nrow(t) > 0) {
        updateMetadataForTags(t)
        return(TRUE)
    }
    return(FALSE)
}
