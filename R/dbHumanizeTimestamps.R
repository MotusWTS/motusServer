#' create a view of a table where timestamps are displayed in human-readable
#' form.
#'
#' @details Creates a view of a table where any numeric `timestamp`
#'     field is replaced by a human readble version.  The view will
#'     have the given new name, `timestamp` is judged by having
#'     a name matching the timestamp regex.  If the view
#'     already exists, this function does nothing.
#'
#' @param dbcon connection to a MySQL/MariaDB server or sqlite database
#'
#' @param table name of existing table
#'
#' @param newtable name of new view; default: \code{paste0('_', table)}
#'
#' @param tsRegex regular expression that matches names of columns holding
#' numeric timestamps.  Default:  '^ts.*'
#'
#' @param temporary should view be temporary?  default:FALSE
#'
#' @return TRUE on success; FALSE otherwise.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

dbHumanizeTimestamps = function(dbcon, table, newtable = paste0('_', table), tsRegex = '^ts.*', temporary=FALSE) {
    if (inherits(dbcon, "MySQLConnection")) {
        formatFN = function(n) sprintf("from_unixtime(%s) as %s", n, n)
        queryTemplate = "CREATE ALGORITHM = MERGE %s VIEW IF NOT EXISTS %s AS SELECT %s from %s"
    } else {
        formatFN = function(n) sprintf("datetime(%s, 'unixepoch') as %s", n, n)
        queryTemplate = "CREATE %s VIEW IF NOT EXISTS %s AS SELECT %s from %s"
    }
    cols = dbListFields(dbcon, table)
    outs = ifelse(grepl(tsRegex, cols, perl=TRUE), formatFN(cols), cols)
    query = sprintf(queryTemplate,
                    if (temporary) "TEMPORARY" else "",
                    newtable,
                    paste0(outs, collapse=","),
                    table)
    dbExecute(dbcon, query)
    return(TRUE)
}
