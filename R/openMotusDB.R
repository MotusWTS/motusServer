#' Return a src_mysql attached to the motus mysql database.
#'
#' The motus database holds batches of tag detections intended for the
#' motus server.  This must be run by a user who has permissions to
#' the mysql motus database on the local server, and whose password to
#' that database is stored in the file ~/.secrets/motusSecrets as
#' element "dbPasswd".
#'
#' @param dbname database name; default: "motus"
#'
#' @param host hostname or IP address; default: "localhost"
#'
#' @param user user on database; default: "motus"
#'
#' @param sock location of socket for database; default: "/var/run/mysqld/mysqld.sock"
#'
#' @return object of class \link{\code{safeSQL}}
#'
#' @note The safeSQL objects is stored in the global variable MotusDB, and
#'     if that variable already exists, the connection it holds is
#'     used.  This means the DB connection is normally opened at most
#'     once per session.  It is reopened automatically if it has closed.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

openMotusDB = function(dbname="motus", host="localhost", user="motus", sock="/var/run/mysqld/mysqld.sock") {
    tryCatch(
        ## sanity check on connection
        MotusDB("select 1"),
        error = function(e) {
            ## either MotusDB doesn't exist, or connection has expired
            MotusDB <<- safeSQL(dbConnect(MySQL(), dbname=dbname, host=host, user=user, password=MOTUS_SECRETS$dbPasswd, sock))
        }
    )
    return (MotusDB)
}
