#' Run a function on a single stream of raw data.
#'
#' A stream of data consists of all records from raw files with the
#' same monoBN (montonic boot number), ordered by increasing date.
#' This function lets you run a function on one stream, specified by
#' monoBN.  The stream is broken into chunks corresponding to the
#' original files.  Each chunk is passed as a character scalar which
#' will usually consist of multiple lines, separated by \code{'\n'}.
#' 
#' @param src dplyr src_sqlite to receiver database
#' 
#' @param mbn integer monotonic boot number; this is the monoBN field
#'     from the \code{files} table in the receiver's sqlite database.
#' 
#' @param f function with this signature:
#' \enumerate{
#' \item mbn integer monotonic boot number; same value passed to \code{sgRunStream}
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
#' @param user arbitrary object passed to \code{f} as \code{user}
#'     parameter on each call.  Defaults to NULL.
#' 
#' @return the valued returned by \code{f} when called with
#'     \code{state=2L}; i.e. after \code{f} has been called with every
#'     chunk.  All previous return values of \code{f} are discarded.
#'     Any side-effects or accumulation of return value must be
#'     performed by \code{f}.
#'
#' @examples
#' 
#' ##  u = new.env(emptyenv())
#' ##  a = sgRunStream(
#' ##       s2,
#' ##       18L,
#' ##       function(bn, ts, cno, ct, u) {
#' ##         if (cno < 0){
#' ##            u$ct=vector("list", -cno)
#' ##         } else if (cno > 0) {
#' ##            u$ct[[cno]] = unlist(stri_extract_all_regex(ct, "^G,[-,\\.0-9E]+$", opts_regex=list(multiline=TRUE), omit_no_match=TRUE))
#' ##         } else {
#' ##            return(u$ct)
#' ##         }
#' ##       },
#' ##       u
#' ##     )
#' ##  g = stri_split_regex(unlist(u$ct), "[,\n]", simplify=TRUE, omit_no_match=TRUE)[,-1]
#' ##  class(g) = "numeric" ## preserve dimensions
#' 
#'
#' @export
#' 
#' @note any notes
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgRunStream = function(src, mbn, f, user=NULL) {
    sgEnsureDBTables(src)
    
    if (! is.integer(mbn))
        stop("mbn must be an integer")
    if (!is.function(f) || length(formals(f)) != 5)
        stop("f must be a function accepting 5 parameters")

    ## use low-level DBI functions for speed
    con = src$con
    n = dbGetQuery(
        con,
        sprintf(
            "select count(*) from files where monoBN=%d",
            mbn)
    ) [[1, 1]]

    if (n == 0L) {
        warning("No files for receiver have monoBN ==", mbn)
        return(NULL)
    }

    res <- dbSendQuery(
        con,
        sprintf(
            "select ts, contents from files where monoBN=%d order by ts",
            mbn)
        )

    f(mbn, NULL, -n, NULL, user) ## allow user function to initialize
    
    i = 1L
    while (i <= n) {
        chunk = dbFetch(res, 1)
        f(
            mbn,
            chunk$ts[[1]],
            i,
            chunk$contents[[1]] %>% memDecompress("bzip2", asChar=TRUE),
            user
        )
        i = i + 1L
     }
    dbClearResult(res)
    
    return (f(mbn, NULL, 0L, NULL, user)) ## allow user function to finalize
}
