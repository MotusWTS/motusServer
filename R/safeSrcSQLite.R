#' open a dplyr::src to an sqlite database, without the locking issue
#'
#' By default, \code{dbConnect(RSQLite::SQLite(), ...)} connects and immediately
#' tries to set synchronous mode.  If the database is locked, this
#' fails \emph{before we can use pragma busy_timeout} to set a timeout handler.
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
#' @seealso \code{\link{safeSQLiteConnect}} which this function calls.
#'
#' @author minor changes from dplyr::src_sqlite by John Brzustowski

safeSrcSQLite = function (path, create = FALSE)
{
    dplyr::check_dbplyr()
    con = safeSQLiteConnect(path, create)
    if (is.null(con)) {
        dplyr:::bad_args("path", "must already exist, unless `create` = TRUE")
    }
    RSQLite::initExtension(con)
    dbplyr::src_dbi(con)
}
