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
#' \item method: download method; e.g. googleDrive, wetransferDirect, ...
#' }
#'
#' If \code{type="xxx"}, there must exist a handler called \code{downloadXxx};
#' i.e. the first letter in the type gets capitalized.
#'
#' @return TRUE if the download was successfully handled
#'
#' @note if successful, subjobs to run sanity checks and unpack archives
#' are enqueued.
#'
#' @seealso \link{\code{emailServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDownload = function(j) {

    method = j$method
    url = j$url
    path = j$path

    sanURL = sanitizeURL(url, method)

    getter = get0(paste0("download", toupper(substring(method, 1, 1)), substring(method, 2)), mode="function")
    if (is.null(getter)) {
        jobLog(j, paste0("Download not tried:  unknown method '", method, "' for \n   ", sanURL,
                         "\n  This is probably an unsupported form of Dropbox link; please re-send by
following the instructions here:\n
   https://sensorgnome.org/index.php?title=Sending_Data_for_Automatic_Processing/Sending_Data_for_Automatic_Processing_from_Dropbox&bc=1
"))
        return (FALSE)
    }
    jobLog(j, paste0("Downloading using method '", method, "' for:\n   ", sanURL))
    tryCatch ({
        rv = getter(url, path)
    }, error = function(e) {
        e = paste0(e)
        if (grepl("Not Found", e, ignore.case=TRUE)) {
            e = paste("We failed to download the file or folder you sent.\nEither the link is wrong, or the content has expired.\nPlease try resending.\nCurl error message was: ", e)
            jobLog(j, e)
            return(FALSE)
        }
    })

    jobLog(j, rv)
    newSubJob(j, "sanityCheck", dir=path)
    newSubJob(j, "queueArchives", dir=path)

    return(TRUE)
}
