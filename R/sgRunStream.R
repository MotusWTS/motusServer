#' Run a function on one or more streams of raw data.
#'
#' A stream of raw data consists of all records from raw files with
#' the same monoBN (montonic boot number), ordered by increasing date.
#' This function lets you run a function on one or more streams,
#' specified by monoBN, or all streams.  Each stream is broken into
#' chunks corresponding to the original files.  Each chunk is passed
#' as a character scalar which will usually consist of multiple lines,
#' separated by \code{'\n'}.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param f function with this signature:
#' \enumerate{
#' \item mbn integer monotonic boot number
#' \item fts numeric file timestamp; the timestamp encoded in the file name
#' \item cno chunk number, as follows:
#' \enumerate{
#' \item negative; chunk and timestamp invalid; called with this value only once, before first chunk; value is number of chunks in stream
#' \item positive; chunk is valid; \code{cno} is index of chunk, starting at 1
#' \item 0L chunk and timestamp invalid; called with this value only once, after last chunk; return value for this call becomes return value of \code{sgRunStream}
#' }
#'
#' \item dat character scalar; the file contents, with embedded newlines
#'
#' \item user; the user object passed to \code{sgRunStream}.  This can
#' be used to maintain state information across calls to \code{f}.
#' Typically, this would be an environment or reference class object.
#' }
#'
#' @param mbn integer vector of monotonic boot numbers; this is the
#'     monoBN field from the \code{files} table in the receiver's
#'     sqlite database.  Defaults to NULL, which means run all streams
#'     in order.
#'
#' @param user arbitrary object passed to \code{f} as \code{user}
#'     parameter on each call.  Defaults to NULL.
#'
#' @return a list with one element per stream; the element is the
#'     valued returned by \code{f} when called with \code{state=2L};
 #'     i.e. after \code{f} has been called with every chunk for the
#'     given stream.  All previous return values of \code{f} are
#'     discarded.  Any side-effects or accumulation of return value
#'     must be performed by \code{f}.
#'
#' @export
#'
#' @note UNUSED
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgRunStream = function(src, f, mbn=NULL, user=NULL) {
    sgEnsureDBTables(src)

    if (! (is.null(mbn) || is.integer(mbn)))
        stop("mbn must be NULL or an integer vector")
    if (!is.function(f) || length(formals(f)) != 5)
        stop("f must be a function accepting 5 parameters")

    ## by default, no filtering by mbn
    where = ""
    if (! is.null(mbn))
        where = sprintf("where monoBN in (%s)", paste(mbn, collapse=","))

    con = src$con
    n = dbGetQuery(
        con,
        paste("select monoBN, count(*) as count from files", where, "group by monoBN order by monoBN")
    )

    if (sum(n) == 0L) {
        warning("No files for receiver", if (! is.null(mbn)) " with specified monoBN")
        return(NULL)
    }

    rv = vector("list", nrow(n))

    for(i in seq_len(nrow(n))) {
        mbn = n$monoBN[i]
        count = n$count[i]
        if (count > 0) {
            ## use low-level DBI functions for speed and so we don't have to read
            ## everything into memory at once

            res = dbSendQuery(
                con,
                sprintf("select t1.ts as ts, t2.contents as contents from files as t1 join fileContents as t2 on t1.fileID=t2.fileID where t1.monoBN==%d order by t1.ts", mbn)
            )

            f(mbn, NULL, -count, NULL, user) ## initialize new stream
            j = 1L
            while (j <= count) {
                chunk = dbFetch(res, 1)
                f(
                  mbn,
                  chunk$ts[[1]],
                  j,
                  if (length(chunk$contents[[1]]) > 0)
                      chunk$contents[[1]] %>% memDecompress("bzip2", asChar=FALSE)
                  else
                      raw(0)
                 ,
                  user
                )
                j = j + 1L
            }
            rv[[i]] = f(mbn, NULL, 0L, NULL, user)
            dbClearResult(res)
        }
    }
    return (rv) ## finalize last stream
}
