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
#' @param n number of consecutive keys to reserve.  If negative, the
#'     keys are reserved in descending order, starting at the smallest
#'     (i.e. most negative) available value.  For a given table, keys
#'     should always be reserved with \code{n} of the same sign;
#'     i.e. keys should always be allocated ascending order, or always
#'     allocated in descending order.
#'
#' @param maxKeyTable name of the table in which maximum key values
#' are recorded; this must have (at least) these fields:
#' \itemize{
#'    \item tableName UNIQUE CHAR name of table
#'    \item maxKey BIGINT maximum magnitude of a key in the table
#' }
#' Default: "maxKeys"
#'
#' @return the first key value in the block.  For positive \code{n}, this
#' is the lowest key value in the block.  For negative \code{n}, this is
#' the highest key value. i.e. in both cases, keys are allocated in order
#' from closest to 0 to farther from 0.
#'
#' @examples
#'
#' ## return the first key in a block of 200 reserved in the batches table
#' motusReserveKeys("batches", 200)
#'
#' @note this function uses the table maxKeys to track the maximum
#'     (magnitude of a) key in any table of interest.  The
#'     implementation is cooperative: all keys in any table this
#'     function is used for must be obtained by using this function.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusReserveKeys = function(table, n, maxKeyTable="maxKeys") {

    ## atomically increment the record in maxKeyTable with tableName == table
    ## Note the use of max(maxKey) to cover the case where no current entry exists
    ## for the given table.  Otherwise, the select query has an empty result and
    ## no new record is inserted into maxKeyTable.

    MotusDB("replace into %s (tableName, maxKey) select '%s', @maxKey := ifnull(max(maxKey), 0) + %d from %s where tableName='%s' for update",
            maxKeyTable, table, abs(n), maxKeyTable, table, .QUOTE=FALSE)

    ## Now fetch the value of maxKey which we stored in a connection
    ## variable so that its value is indifferent to changes by other
    ## processes between the query above and the one below.

    maxKey = MotusDB("select @maxKey")[[1]]
    if (n >= 0)
        return (maxKey - n + 1)
    else
        return (- (maxKey + n + 1))
}
