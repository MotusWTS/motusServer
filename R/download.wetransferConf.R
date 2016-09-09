#' Download a file specified by a wetransfer.com "confirmation email" link.
#'
#' The confirmation email sent from wetransfer.com to a file sender
#' contains a shortened link to the downloadable file.  That file is
#' downloaded into the specified directory.
#'
#' @param link URL of file on wetransfer.com, from confirmation email
#' sent to file sender.
#'
#' @param dir directory into which the file(s) will be downloaded
#'
#' @return returns invisible(NULL)
#'
#' @note wetransfer.com does not have a published download API, so we
#'     do this the tedious way, by parsing responses from their
#'     server.  Watch for changes to the format of emails and server
#'     replies that might break this fragile code.
#'
#' @seealso \link{\code{download.wetransferDirect}} for downloading using
#' the link in an email to the file recipient.
#' 
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

download.wetransferConf = function(link, dir) {

    ## URL from email looks like
    ## e.g. https://we.tl/6gFmMXFkXP

    x = GET(link) ## from package:httr
    
    ## reformat the returned URL:
    ## e.g.
    ## "https://www.wetransfer.com/downloads/f577d5d876d271e0228ac28e2cfd502f20160420213117/6acdc8"
    ## ->
    ## "https://api.wetransfer.com/api/v1/transfers/f577d5d876d271e0228ac28e2cfd502f20160420213117/download?recipient_id=&security_hash=6acdc8&password=&ie=false&ts=1461204325054"
    
    parts = strsplit(x$url, "/", fixed=TRUE)[[1]]
    options(digits=14) ## for getting timestamp as integer
    newURL = sprintf("https://api.wetransfer.com/api/v1/transfers/%s/download?recipient_id=&security_hash=%s&password&ie=false&ts=%.0f",
                     parts[5],
                     parts[6],
                     round(as.numeric(Sys.time()) * 1000)
                     )
    y = GET(newURL, set_cookies(unlist(x$cookies[2])))
    directLink = fromJSON(rawToChar(y$content))$direct_link
    file = basename(parse_url(directLink)$path)
    file = file.path(dir, sub("[/~]", "", file, perl=TRUE))
    f = CFILE(file, "wb")
    curlPerform(url=directLink, writedata=f@ref)
    RCurl::close(f)
    invisible(NULL)
}
