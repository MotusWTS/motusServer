#' Try to lock or unlock a symbol, preventing any other cooperating motusServer process
#' from using it.
#'
#' This is mainly to prevent interleaved access to receiver and other databases.
#'
#' @param symbol character scalar; this can be a receiver serial
#'     number, database filename, or other arbitrary unique symbol.
#'
#' @param owner integer; defaults to id of process trying to lock the
#'     symbol, but any integer uniquely associated with the process
#'     can be used. The owner is recorded in the symLocks table of the
#'     motus server database when locking is successful (indeed,
#'     'successful' means that after attempting to lock the symbol,
#'     the owner associated with it is this parameter).
#'
#' @param lock logical scalar; if TRUE, try unlock the receiver;
#'     otherwise, release any lock.
#'
#' @return if \code{lock} is \code{TRUE}, then return TRUE if this
#'     process now has an exclusive lock on the symbol, otherwise
#'     FALSE.  If \code{lock} is \code{FALSE}, then always return
#'     TRUE.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

lockSymbol = function(symbol, owner=Sys.getpid(), lock=TRUE) {
    ## Note: the locking is achieved by the UNIQUE PRIMARY KEY property on symbol

    if (lock) {
        ## try to lock this serial number to our process number; this
        ## fails at the sqlite level if there's already a lock on the
        ## receiver; i.e. if there's already a record in symLocks with
        ## the given symbol.  However, to cover the case where the
        ## lock is ours, e.g. due to sloppy coding in this package, we
        ## don't use this exception to determine whether locking
        ## succeeded.  All we're interested in is whether \code{owner}
        ## really does own the symbol; that's what "success" means here.

        try(
            MOTUS_SERVER_DB_SQL(sprintf("INSERT INTO %s VALUES(:symbol, :owner)", MOTUS_SYMBOLIC_LOCK_TABLE),
                                symbol = symbol,
                                owner = owner),
            silent = TRUE)

        ## return logical indicating whether locking succeeded

        return (isTRUE(owner == MOTUS_SERVER_DB_SQL(sprintf("SELECT owner from %s where symbol=:symbol", MOTUS_SYMBOLIC_LOCK_TABLE),
                                                            symbol = symbol)[[1]]))
    }
    MOTUS_SERVER_DB_SQL(sprintf("DELETE FROM %s where symbol=:symbol", MOTUS_SYMBOLIC_LOCK_TABLE),
                    symbol = symbol)
    return (TRUE)
}
