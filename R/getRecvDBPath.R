#' Get the path to a receiver database given its serial number.
#'
#' receiver database files are stored in a single directory, and
#' have names like "SG-XXXXBBBKYYYY.motus" or "Lotek-NNNNN.motus"
#'
#' @param serno receiver serial number
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{MOTUS_PATH$RECV}
#'
#' @return a character scalar giving the full path to the receiver database,
#' or NULL if \code{serno} is not a valid receiver serial number
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getRecvDBPath = function(serno, dbdir = MOTUS_PATH$RECV) {
    if (!grepl(MOTUS_RECV_SERNO_REGEX, serno))
        return (NULL)
    return(file.path(dbdir, paste0(serno, ".motus")))
}
