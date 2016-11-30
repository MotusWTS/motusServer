#' Parse an email message for links to downloadable content, and queue
#' them for download.
#'
#' The links must be of the forms specified in \link{\code{dataTransferRegex}}
#' We queue a download subjob for each link.
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
    links = links[! duplicated(links)]  ## can't use 'unique' as it drops names

    ## queue any links

    for (i in seq(along=links)) {
        newSubJob(j, "download", .makeFolder=TRUE, url=links[i], method=names(links)[i])
    }
}
