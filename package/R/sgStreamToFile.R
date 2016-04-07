#' Send a stream of raw data to a file
#'
#' A stream of raw data consists of all records from raw files with
#' the same monoBN (montonic boot number), ordered by increasing date.
#' This function lets you write one or more streams,
#' specified by monoBN, or all streams, to a file.  Typically,
#' this file is a fifo with a reader, such as the tag finder.
#' 
#' @param src dplyr src_sqlite to receiver database
#' 
#' @param f output filename
#'
#' @param mbn integer vector of monotonic boot numbers; this is the
#'     monoBN field from the \code{files} table in the receiver's
#'     sqlite database.  Defaults to NULL, which means run all streams
#'     in order.
#' 
#' @return invisible NULL
#'
#' @export
#' 
#' @note any notes
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgStreamToFile = function(src, f, mbn=NULL) {
    if (! (is.null(mbn) || is.integer(mbn)))
        stop("mbn must be NULL or an integer vector")
    
    if (!is.character(f) || length(f) != 1)
        stop("f must be a character scalar")

    ## by default, no filtering by mbn
    where = ""
    if (! is.null(mbn))
        where = sprintf("where t1.monoBN in (%s)", paste(mbn, collapse=","))
    
    dbGetQuery(
        src$con,
        sprintf("select writefile('%s', bz2uncompress(t2.contents, t1.size)) from files as t1 join fileContents as t2 on t1.fileID=t2.fileID %s order by t1.monoBN, t1.ts", f, where)
    )
    return(invisible(NULL))
}
