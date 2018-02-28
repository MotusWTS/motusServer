#' Return a src_mysql attached to the motus mysql database.
#'
#' The motus database holds batches of tag detections merged from all
#' receiver databases.  This function must be run by a user who has
#' permissions to the mysql motus database on the local server, and
#' whose password to that database is stored in the file
#' ~/.secrets/motusSecrets as element "dbPasswd".
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
    dbConOkay = FALSE
    n = 0
    repeat {
        tryCatch(
        {
            if (! exists("MotusDB", .GlobalEnv)) {
                MotusDB <<- safeSQL(dbConnect(MySQL(), dbname=dbname, host=host, user=user, password=MOTUS_SECRETS$dbPasswd, sock))
                dbConOkay = TRUE
            } else {
                ## sanity check on connection:  update a counter that forces
                ## the innoDB storage engine to touch files on the NAS
                MotusDB("update bumpCounter set n=n+1 where k=0")
                dbConOkay = TRUE
            }
        },
        error = function(e) {
            ## invalidate the global MotusDB
            rm("MotusDB", pos=.GlobalEnv)
            ## wait before trying to reconnect
            Sys.sleep(5)
        }
        )
        if (dbConOkay)
            break
        n = n + 1
        if (n > 10)
            stop("unable to (re)connect to mariaDB motus database server")
    }
    return (MotusDB)
}
