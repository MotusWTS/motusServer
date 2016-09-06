#' Parse an email message for links to downloadable content, and handle
#' these.
#'
#' The links must be of the forms specified in \link{\code{dataTransferRegex}}
#'
#' @param msg character scalar; the message text.
#'
#' @return no return value.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleDownloadableLinks = function(msg) {

    links = regexPieces(dataTransferRegex, msg)[[1]]

    ## call handlers for any links, downloading the file(s) to
    ## its own temporary subdirectory

    for (i in seq(along=links)) {

        motusLog("Calling download.%s for %s", names(links)[i], links[i])
        tmpdir = motusTempPath()

        ## handlers are called 'download.XXX' where XXX is the link type,
        ## e.g. 'dropbox'
        get(paste0("download.", names(links)[i])) (links[i], tmpdir)

        ## move the temporary directory to the incoming folder
        ## (giving it a unique name there) so the server function sees it

        enqueue(tmpdir)
    }
}
