#' Get the src_sqlite for a receiver database given its serial number.
#'
#' receiver database files are stored in a single directory, and
#' have names like "SG-XXXXBBBKYYYY.motus" or "Lotek-NNNNN.motus"
#'
#' @param serno receiver serial number
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{MOTUS_PATH$RECV}
#'
#' @param create logical scalar; if TRUE, create the database if it doesn't
#' already exist.
#'
#' @return a src_sqlite for the receiver; if the receiver is new, and \code{create==TRUE} this database
#' will be empty, but have the correct schema.  If the receiver is new and \code{create==FALSE},
#' return \code{NULL}.  If \code{serno} does not have the form of a valid serial number,
#' raise an error.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getRecvSrc = function(serno, dbdir = MOTUS_PATH$RECV, create=TRUE) {
    path = getRecvDBPath(serno, dbdir)
    if (is.null(path))
        stop("invalid receiver serial number ", serno)
    if (! create && ! file.exists(path))
        return(NULL)
    src = safeSrcSQLite(path, TRUE)
    ensureRecvDBTables(src, serno=serno)
    return(src)
}
