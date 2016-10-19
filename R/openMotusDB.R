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
#' @return object of class dplyr::src_mysql
#'
#' @note The src_mysql is stored in the global variable MOTUS_DB, and
#'     if that variable already exists, the connection it holds is
#'     used.  This means the DB connection is normally opened at most
#'     once per session.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

openMotusDB = function(dbname="motus", host="localhost", user="motus") {
    if (exists("MOTUS_DB") && inherits(MOTUS_DB, "src_mysql")))
        return(MOTUS_DB)
    return (MOTUS_DB <<- src_mysql(dbname=dbname, host=host, user=user, password=MOTUS_SECRETS$dbPasswd))
}
