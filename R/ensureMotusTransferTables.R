#' Ensure we have the mysql transfer tables for moving SG data to
#' motus.
#'
#' @param recreate vector of table names which should be dropped then re-created,
#' losing any existing data.  Defaults to empty vector, meaning no tables
#' are recreate.
#'
#' @note: assumes \link{\code{openMotusDB()}} has been called, so that
#' the global variable MotusDB is set.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureMotusTransferTables = function(recreate=c()) {

    if (isTRUE(recreate))
        recreate = motusTransferTables

    have = dbListTables(MotusDB$con)
    need = ! motusTransferTables %in% have
    if (! any(need) && length(recreate) == 0)
        return ()

    for (t in recreate)
        try(MotusDB("drop table %s", t), silent=TRUE)

    schema = "motusTransferTableSchema.sql" %>%
        system.file(package="motusServer") %>%
        readLines %>%
        paste(collapse="\n") %>%
        strsplit(";--", fixed=TRUE)

    for (s in schema[[1]])
        MotusDB(s)

    return ()
}

motusTransferTables = c("batches", "gps", "runs", "runUpdates",
                        "hits", "batchAmbig", "batchProgs",
                        "batchParams", "batchDelete", "maxKeys", "bumpCounter", "uploads",
                        "reprocess", "reprocessBootSessions", "reprocessBatches")
