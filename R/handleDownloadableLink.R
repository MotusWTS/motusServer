#' Grab content from a downloadable link.
#'
#' The link is contained a file whose name looks like url_XXX.txt
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
#' @return TRUE if \code{path} contained a link which was
#'     successfully downloaded.
#'
#' If the content is successfully downloaded, it is enqueued.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDownloadableLink = function(path, isdir) {

    if (isdir || ! grepl(MOTUS_DOWNLOADABLE_LINK_FILE_REGEX, path, perl=TRUE))
        return (FALSE)

    s = readLines(path, n=1) %>% strsplit(" ", fixed=TRUE)[[1]]

    ## try call a function called 'download.TYPE'

    getter = get0(paste0("download.", s[1]), mode="function")
    if (is.null(getter))
        return (FALSE)

    tmpdir = motusTempPath()
    motusLog("Downloading to %s type=%s url=%s", tmpdir, s[1], s[2])
    getter(s[2], tmpdir)
    enqueue(tmpdir)
}
