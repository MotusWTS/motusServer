#' Return the database of canonical parameters for a Lotek codeset.
#'
#' This function returns a dplyr data_frame with the nominal gap
#' values for all Lotek tag IDs in the specified codeset.
#'
#' @param codeSet: character scalar; only "Lotek3" or "Lotek4"
#' are permitted so far.
#'
#' @param pathOnly: logical scalar; if TRUE, return only the path
#' to the .sqlite database containing the codeset.  Default: FALSE
#'
#' @return a dplyr data_frame with these columns:
#'
#' \itemize{
#' \item id tag ID
#' \item g1 gap between 1st, 2nd pulses, in ms
#' \item g2 gap between 2nd, 3rd pulses, in ms
#' \item g3 gap between 3rd, 4th pulses, in ms
#' }
#'
#' @note This function will only work on the sensorgnome.org server,
#'     where we have Lotek's permission to host an encrypted copy of
#'     their ID code database.  At server boot time, a user with sudo
#'     privileges must run a script to decrypt the database into
#'     locked system memory, from where it can only be accessed by
#'     user "sg" (or, of course, those with sudo privileges).  The
#'     decrypted versions reside in
#'
#'     /home/sg/ramfs/Lotek4.sqlite and
#'     /home/sg/ramfs/Lotek3.sqlite
#'
#'     while the encrypted versions are in /home/sg/lotekdb
#'
#'     The decryption script is in /home/sg/bin/decryptLotekDB.R
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ltGetCodeset = function(codeSet = c("Lotek4", "Lotek3"), pathOnly=FALSE) {
    codeSet = match.arg(codeSet)

    fn = sprintf("/home/sg/ramfs/%s.sqlite", codeSet)

    if (pathOnly)
        return(fn)

    if (Sys.getenv("USER") %in%  c("root", "sg") && file.exists(fn)) {
        con = dbConnect(SQLite(), fn)
        dbExecute(con, "pragma busy_timeout=300000")
        rv = dbGetQuery(con, "select id, g1, g2, g3 from tags order by id")
        dbDisconnect(con)
    } else {
        stop("Attempt to access Lotek database by non-sg user, or database doesn't exist")
    }
    return(rv)
}
