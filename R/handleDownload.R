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
#' @param j the download job; it has these fields:
#' \itemize{
#' \item url: download URL
#' \item type: download type
#' }
#'
#' If \code{type="xxx"}, there must exist a handler called \code{downloadXxx};
#' i.e. the first letter in the type gets capitalized.
#'
#' @return TRUE if the download was successfully handled
#'
#' @seealso \link{\code{emailServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDownload = function(j) {

    ## try call a function called 'download.TYPE'
    type = j$type
    url = j$url
    path = j$path

    getter = get0(paste0("download", toupper(substring(type, 1, 1)), substring(type, 2)), mode="function")
    if (is.null(getter)) {
        motusLog("Download failed; unknown type '%s' for URL '%s'", type, url)
        return (FALSE)
    }
    motusLog("Downloading to %s type=%s url=%s", path, type, url)
    j$message = getter(url, path)
    return(TRUE)
}
