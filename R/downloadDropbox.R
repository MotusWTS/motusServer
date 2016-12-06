#' Grab a file or folder specified by a dropbox shared link.
#'
#' Download the file or folder (recursively) from a URL pointing to
#' shared content on dropbox.com into the specified directory.
#'
#' @param link URL of file or folder on dropbox.com, from the email
#' sent to the file or folder recipient.
#'
#' @param dir directory into which the file(s) will be downloaded
#'
#' @return message stating how many bytes were downloaded.
#'
#' @note This will not work with the URL in the email that dropbox
#'     generates when a user chooses to share a file in the most
#'     obvious (to me) way!  Rather, the user must explicitly create a
#'     link that permits anyone to view the file, then manually email
#'     it to us.  We have filed a feature request on this [1].
#'
#' @export
#'
#' @references \link{https://www.dropboxforum.com/hc/en-us/community/posts/206649516-Import-Email-shared-file-by-api-?page=1#community_comment_212400843}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

downloadDropbox = function(link, dir) {

    ## URL from email looks like
    ## e.g. https://www.dropbox.com/sh?/biie8sdq0oc5jm6/testfile.txt?dl=0
    ##
    ## FIXME: to get valid filename from /sh/ links,
    ## grab true filename using e.g.  curl -X POST
    ## https://api.dropboxapi.com/2/sharing/get_shared_link_metadata
    ## --header "Authorization: Bearer XXX
    ## --header "Content-Type: application/json" --data "{\"url\":
    ## \"https://www.dropbox.com/sh/u0q66gy0cetwe5k/AACIXlLrNmIgexPHbz197ciQa?dl=0\"}"
    ##
    ## with Bearer token replacing XXX

    ## parse out the filename
    file = parse_url(link)$path %>% basename
    dest = file.path(dir, file)

    f = CFILE(dest, "wb")

    ## as per dropbox docs, change dl parameter to 1 (doesn't seem to be required)
    url = sub("dl=0$", "dl=1", link, perl=TRUE)

    curlPerform(url=url, followLocation = TRUE, writedata=f@ref)

    RCurl::close(f)
    return(sprintf("Downloaded %.0f bytes for file %s", file.info(dest)$size, file))
}
