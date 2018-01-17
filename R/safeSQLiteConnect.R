#' open a 'safe' connection to an sqlite database
#'
#' In this package, all connections to sqlite database files are created
#' by this function.
#'
#' This avoids the locking issue with the typical use of
#' \code{dbConnect(RSQLite::SQLite(), ...)}, which connects and immediately
#' tries to set synchronous mode, unless \code{synchronous=NULL} is specified.
#' If the database is locked, the connection fails \em{before \code{pragma busy_timeout}}
#' can be used to set a timeout handler.
#'
#' @param path path to database
#'
#' @param create should database be created if it doesn't already exist; default: FALSE
#'
#' @param busyTimeout value for busy_timout handler, in seconds;
#'     default: 300.  A positive value causes the function to wait
#'     for another process to unlock the database, rather than returning
#'     immediately with an error.
#'
#' @return a DBI:dbConnection to the sqlite database, or NULL on failure
#'
#' @note parameters, return value, and semantics are identical to
#' \code{\link{dplyr::src_sqlite}} except that a locked sqlite database
#' will be handled gracefully with retries.
#'
#' @export
#'
#' @author minor changes from dplyr::src_sqlite by John Brzustowski

safeSQLiteConnect = function (path, create = FALSE, busyTimeout=300)
{
    con = NULL
    if (create || file.exists(path)) {
        try({
            con = DBI::dbConnect(RSQLite::SQLite(), path, synchronous=NULL)
            DBI::dbExecute(con, sprintf("pragma busy_timeout=%d", busyTimeout * 1000))
            DBI::dbExecute(con, "pragma synchronous=off")
        }, silent=TRUE)
    }
    return(con)
}
