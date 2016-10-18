#' Parse an email message for links to downloadable content, and queue
#' them for download.
#'
#' The links must be of the forms specified in \link{\code{dataTransferRegex}}
#' Each link is written to a temporary file in this format:
#'
#' \code{
#'   TYPE URL
#' }
#' where \code{TYPE} is the kind of download link, e.g. 'dropbox' or 'googleDrive'
#' and \code{URL} is its location.  The file is then passed to \link{\code{enqueue()}}
#' with parameters \code{pattern='url_', fileext='.txt'}
#'
#' @param j job for which downloads will be subjobs
#'
#' @param msg character scalar; the message text.
#'
#' @return no return value.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

queueDownloads = function(j, msg) {

    links = regexPieces(dataTransferRegex, msg)[[1]]

    ## queue any links

    for (i in seq(along=links))
        queueJob(newSubJob(j, "download", url=links[i], type=names(links)[i]))
}
