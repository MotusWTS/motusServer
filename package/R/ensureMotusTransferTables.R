#' Ensure we have the mysql transfer tables for moving SG data to
#' motus.
#'
#' @param src dplyr::src_mysql to motus transfer database
#'
#' @param recreate vector of table names which should be dropped then re-created,
#' losing any existing data.  Defaults to empty vector, meaning no tables
#' are recreate.
#' 
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureMotusTransferTables = function(src, recreate=c()) {
    if (! inherits(src, "src_mysql"))
        stop("src is not a dplyr::src_mysql object")
    con = src$con
    if (! inherits(con, "MySQLConnection"))
        stop("src is not open or is corrupt; underlying db connection invalid")

    ## function to send a single statement to the underlying connection
    sql = function(...) dbGetQuery(con, sprintf(...))   

    if (isTRUE(recreate))
        recreate = motusTransferTables
    
    have = src_tbls(src)
    need = ! motusTransferTables %in% have
    if (! any(need) && length(recreate) == 0)
        return ()

    for (t in recreate)
        try(sql("drop table %s", t), silent=TRUE)

    schema = "motusTransferTableSchema.sql" %>%
        system.file(package="motus") %>%
        readLines %>%
        paste(collapse="\n") %>%
        strsplit(";--", fixed=TRUE)

    for (s in schema[[1]])
        sql(s)
    
    return ()
}

motusTransferTables = c("batches", "gps", "runs", "runUpdates",
                        "hits", "batchAmbig", "batchProgs",
                        "batchParams", "batchDelete")

