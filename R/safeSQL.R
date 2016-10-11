#' Return a function that safely performs sql queries on a connection,
#' by use of dbGetPreparedQuery when needed.  This prevents e.g.
#' SQL injection attacks.
#'
#' @param con RSQLite connection to database, as returned by
#'     dbConnect(SQLite(), ...), or character scalar giving path
#'     to SQLite database
#'
#' @param busyTimeout how many total seconds to wait while retrying a
#'     locked database.  Default: 10.  Uses \code{pragma busy_timeout}
#'     to allow for inter-process DB locking.
#'
#' @return a function taking two or more parameters:
#' \itemize{
#'
#' \item \code{query} sqlite query; parameters are words beginning
#' with ":"
#'
#' \item \code{...} list of named items specifying values for named
#' parameters in query.  e.g. if \code{query} contains the named
#' parameters \code{:address} and \code{:phone}, then \code{...} must
#' look like \code{address=c("123 West Blvd, Truro, NS",
#' "5 East St., Digby, NS"), phone=c("902-555-1234", "902-555-6789")}
#' These items are passed to \code{data.frame}, along with the
#' parameter \code{stringsAsFactors=FALSE}.
#'
#' \item \code{.CLOSE} boolean scalar; if TRUE, close the underlying
#' database connection, disabling further use of this function.
#'
#' }
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

safeSQL = function(con, busyTimeout = 10) {
    if (is.character(con))
        con = dbConnect(SQLite(), con)
    dbGetQuery(con, paste0("pragma busy_timeout=", round(busyTimeout * 1000)))
    function(query, ..., .CLOSE=FALSE) {
        if (.CLOSE) {
            dbDisconnect(con)
            return(con <<- NULL)
        }
        if (length(list(...)) > 0) {
            dbGetPreparedQuery(con, query, data.frame(..., stringsAsFactors=FALSE))
        } else {
            dbGetQuery(con, query)
        }
    }
}
