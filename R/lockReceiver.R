#' try to lock or unlock a receiver, preventing any other processServer() processes from
#' using it.
#'
#' This prevents interleaved access while running the tag finder for a receiver.
#'
#' @param serno receiver serial number
#'
#' @param lock logical scalar; if TRUE, try unlock the receiver; otherwise, release
#' any lock.
#'
#' @return if \code{lock} is \code{TRUE}, then return TRUE if this process now has an exclusive lock on the receiver, otherwise FALSE.
#' If \code{lock} is \code{FALSE}, then always return TRUE.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

lockReceiver = function(serno, lock=TRUE) {
    ## Note: the locking is achieved by the UNIQUE PRIMARY KEY property on serno

    if (lock) {
        ## try to lock this serial number to our process number
        MOTUS_SERVER_DB(sprintf("INSERT INTO %s VALUES(:serno, :N)", MOTUS_RECEIVER_LOCK_TABLE),
                        serno = serno,
                        N = MOTUS_PROCESS_NUM)

        ## return logical indicating whether locking succeeded

        return (isTRUE(MOTUS_PROCESS_NUM == MOTUS_SERVER_DB(sprintf("SELECT procNum from %s where serno=:serno", MOTUS_RECEIVER_LOCK_TABLE),
                                                            serno = serno)[[1]]))
    }
    MOTUS_SERVER_DB(sprintf("DELETE FROM %s where serno=:serno and procNum = :N", MOTUS_RECEIVER_LOCK_TABLE),
                    serno = serno,
                    N = MOTUS_PROCESS_NUM)
    return (TRUE)
}
