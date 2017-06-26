#' Reserve a block of consecutive primary keys in a motus transfer table.
#'
#' This function returns the first key value in a block of N consecutive
#' key values for the specified table.  These key values are atomically
#' reserved, and guaranteed not to collide with key values for any other
#' receiver, provided every process updating the database uses this function.
#' This permits multiple processes to be pushing data to
#' motus (via populating the transfer tables) at the same time.
#'
#' @param table name of the table in which to reserve keys.
#'
#' @param key name of the key column in table \code{table}.  This
#'     column must be an INT (or BIGINT) PRIMARY KEY.
#'
#' @param n number of consecutive keys to reserve.  If negative, the
#'     keys are reserved in descending order, starting at the smallest
#'     (i.e. most negative) available value.  For a given table, keys
#'     should always be reserved with \code{n} of the same size;
#'     i.e. keys should always be allocated ascending order, or always
#'     allocated in descending order.  Default: "maxKeys".
#'
#' @param maxKeyTable name of the table in which maximum key values
#' are recorded; this must have (at least) these fields:
#' \itemize{
#'    \item tableName UNIQUE CHAR name of table
#'    \item maxKey BIGINT maximum magnitude of a key in the table
#' }
#'
#' @return the first key value in the block.  For positive \code{n}, this
#' is the lowest key value in the block.  For negative \code{n}, this is
#' the highest key value. i.e. in both cases, keys are allocated in order
#' from closest to 0 to farther from 0.
#'
#' @examples
#'
#' ## return the first key in a block of 200 reserved in the batches table
#' motusReserveKeys("batches", "batchID", 200)
#'
#' @note this function uses the table maxKeys to track the maximum
#'     (magnitude of a) key in any table of interest.  The
#'     implementation is cooperative: all keys in any table this
#'     function is used for must be obtained by using this function.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusReserveKeys = function(table, key, n, maxKeyTable="maxKeys") {

    ## Insert a new record at the last new key value we want in the
    ## block.  The entire query, including nested select, is atomic,
    ## so if multiple processes are trying to reserve blocks, they
    ## won't overlap.  Note that all keys for the given table must be
    ## allocated by using this function, so the atomicity is
    ## cooperative.

    MotusDB("replace into %s (tableName, maxKey) select '%s', @maxKey := ifnull(max(maxKey), 0) + %d from %s where tableName='%s'",
            maxKeyTable, table, abs(n), maxKeyTable, table, .QUOTE=FALSE)

    ## Now fetch the value of maxKey which we stored in a connection
    ## variable so that its value is indifferent to changes by other
    ## processes between the query above and the one below.

    maxKey = MotusDB("select @maxKey")[[1]]
    if (n >= 0)
        return (maxKey - n + 1)
    else
        return (- (maxKey - n + 1))
}
