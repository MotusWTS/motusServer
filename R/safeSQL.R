#' Return a function that safely performs sql queries on a connection.
#'
#' This uses dbGetPreparedQuery (for RSQLite) or dbEscapeStrings
#' (for MySQL).  It should prevent e.g. SQL injection attacks.
#'
#' @param con RSQLite connection to database, as returned by
#'     dbConnect(SQLite(), ...), or character scalar giving path
#'     to SQLite database, or MySQLConnection.
#'
#' @param busyTimeout how many total seconds to wait while retrying a
#'     locked database.  Default: 30.  Uses \code{pragma busy_timeout}
#'     to allow for inter-process DB locking.  Only implemented for
#'     SQLite connections.
#'
#' @return a function, S, taking two or more parameters:
#' \itemize{
#' \item \code{query} sqlite query; parameters are:
#' \itemize{
#' \item words beginning with ":" for RSQLite,
#' \item sprintf-style formatting codes (e.g. "%d") for MySQL
#' }
#'
#' \item \code{...} list of named (RSQLite) or unnamed (MySQL) items
#' specifying values for parameters in query.
#' For RSQLite, these items are passed to \code{data.frame}, along with the
#' parameter \code{stringsAsFactors=FALSE}.
#' \itemize{
#' \item \emph{SQLite example}:
#' \code{
#' S("insert into contacts values(:address, :phone)", address=c("123 West Blvd, Truro, NS", "5 East St., Digby, NS"), phone=c("902-555-1234", "902-555-6789"))
#' }
#' \item \emph{MySQL example}:
#' \code{
#' S("insert into contacts values(\"%s\", \"%s\")", "123 West Blvd, Truro, NS", "902-555-1234")
#' S("insert into contacts values(\"%s\", \"%s\")", "5 East St., Digby, NS", "902-555-6789")
#' }
#' }
#'
#' \item \code{.CLOSE} boolean scalar; if TRUE, close the underlying
#' database connection, disabling further use of this function.
#'
#' }
#'
#' Note that for MySQL, only one line of an insert can be provided per call.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

safeSQL = function(con, busyTimeout = 10) {
    if (is.character(con))
        con = dbConnect(SQLite(), con)
    isSQLite = inherits(con, "SQLiteConnection")
    if (isSQLite) {

        ########## RSQLite ##########

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
    } else {

        ########## MySQL ########

        function(..., .CLOSE=FALSE) {
            if (.CLOSE) {
                dbDisconnect(con)
                return(con <<- NULL)
            }
            a = list(...)
            if (length(a) > 1) {
                ## there are some paramters to the query, so escape those which are strings
                a = c(a[[1]], lapply(a[-1], function(x) if (is.character(x)) dbEscapeStrings(con=con, x) else x ))
            }
            q = do.call(sprintf, a)
            dbGetQuery(con, q)
        }
    }
}
