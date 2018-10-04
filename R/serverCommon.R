#' common code required by all XXXServer() functions
#'
#' @param withHTTP logical; does this server respond to http requests?
#' default: TRUE
#'
#' @return TRUE
#'
#' @note side effects are to load libraries, open databases, assign to global variables
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

serverCommon = function(withHTTP = TRUE) {

    if (withHTTP) {
        library(Rook)
        library(jsonlite)
        ## set a 2 minute timeout for all requests to motus.org
        ## - see https://github.com/jbrzusto/motusServer/issues/409
        httr::config(httr::timeout(120))
    }

    ## make sure the server database exists, is open, and put a safeSQL object in the global ServerDB
    ## this is the database responsible for managing processing jobs
    ensureServerDB()

    ## open the motus master database, putting a safeSQL object in the global MotusDB
    openMotusDB()

    MotusCon <<- MotusDB$con

    ## open the motus metadata cache DB
    getMotusMetaDB()

    if (withHTTP) {
        ## get user auth database, ensuring it has a valid auth table

        AuthDB <<- safeSQL(MOTUS_PATH$USERAUTH)
        AuthDB("create table if not exists auth (token TEXT UNIQUE PRIMARY KEY, expiry REAL, userID INTEGER, projects TEXT, receivers TEXT, userType TEXT)")
        AuthDB("create index if not exists auth_expiry on auth (expiry)")
    }
    return(TRUE)
}
