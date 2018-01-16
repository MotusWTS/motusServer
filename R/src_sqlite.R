#' open a dplyr::src to an sqlite database, without the locking issue
#'
#' By default, \code{dbConnect(RSQLite::SQLite(), ...)} connects and immediately
#' tries to set synchronous mode.  If the database is locked, this
#' fails \em{before we can use pragma busy_timeout} to set a timeout handler.
#' This can be circumvented if \code{synchronous=NULL} is added to the
#' call to dbConnect.
#'
#' So this function just augments \code{dplyr::src_sqlite} with that workaround.
#'
#' @param path path to database
#'
#' @param create should database be created if it doesn't already exist; default: FALSE
#'
#' @return a dplyr::src_sqlite object.
#'
#' @note parameters, return value, and semantics are identical to
#' \code{\link{dplyr::src_sqlite}} except that a locked sqlite database
#' will be handled gracefully with retries.
#'
#' @export
#'
#' @author minor changes by John Brzustowski

src_sqlite = function (path, create = FALSE)
{
    dplyr::check_dbplyr()
    if (!create && !file.exists(path)) {
        dplyr:::bad_args("path", "must already exist, unless `create` = TRUE")
    }
    con <- DBI::dbConnect(RSQLite::SQLite(), path, synchronous=NULL)
    DBI::dbExecute(con, "pragma busy_timeout=300000")
    RSQLite::initExtension(con)
    dbplyr::src_dbi(con)
}
