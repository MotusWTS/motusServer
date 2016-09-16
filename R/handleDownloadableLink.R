#' Grab content from a downloadable link.
#'
#' The link is contained a file whose name looks like TIMESTAMP_url
#' The file contains a single line, with this form:
#'
#'    \code{TYPE URL}
#'
#' where TYPE is the name of a handler, e.g. dropbox for which a function
#' \code{dowload.TYPE} is defined, and \code{URL} is the location
#' of the item.
#'
#' @param path the full path to the file with the download link
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @param params character vector; not used.
#'
#' @return TRUE if the link was successfully downloaded.
#'
#' @note If the download was successful, the file/folder is enqueued.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDownloadableLink = function(path, isdir, params) {

    if (isdir)
        return (FALSE)

    s = (readLines(path, n=1) %>% strsplit(., " ", fixed=TRUE))[[1]]

    ## try call a function called 'download.TYPE'

    getter = get0(paste0("download.", s[1]), mode="function")
    if (is.null(getter))
        return (FALSE)

    tmpdir = makeQueuePath("download")
    motusLog("Downloading to %s type=%s url=%s", tmpdir, s[1], s[2])
    motusLog(paste0(getter(s[2], tmpdir), collapse="\n   "))
    enqueue(tmpdir)
    return(TRUE)
}
