#' Return the database of canonical parameters for a Lotek codeset.
#'
#' This function returns a dplyr data_frame with the nominal gap
#' values for all Lotek tag IDs in the specified codeset.
#'
#' @param codeSet: character scalar; only "Lotek-3" or "Lotek-4"
#' are permitted so far.
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
#'     users with sudo privileges.  The decrypted version resides in
#'
#'     /home/sg/ramfs/Lotek-4.sqlite and
#'     /home/sg/ramfs/Lotek-3.sqlite
#'
#'     while the encrypted versions are in /home/sg/lotekdb
#' 
#'     The decryption script is in /home/sg/bin/decryptLotekDB.R
#' 
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ltGetCodeset = function(codeSet = c("Lotek-4", "Lotek-3")) {
    codeSet = match.arg(codeSet)

    fn = sprintf("/home/sg/ramfs/%s.sqlite", codeSet)

    db = system(
        sprintf("sudo su -c 'sqlite3 -header -separator , %s \"select id, g1, g2, g3 from tags order by id\"' sg",
                fn
                ),
        intern=TRUE)

    return(read.csv(textConnection(db), as.is=TRUE))
}

