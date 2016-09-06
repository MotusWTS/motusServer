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
#' @return returns invisible(NULL)
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

download.dropbox = function(link, dir) {

    ## URL from email looks like
    ## e.g. https://www.dropbox.com/s/biie8sdq0oc5jm6/testfile.txt?dl=0

    ## parse out the filename
    file = parse_url(link)$path %>% basename

    f = CFILE(file.path(dir, file), "wb")

    ## as per dropbox docs, change dl parameter to 1 (doesn't seem to be required)
    url = sub("dl=0$", "dl=1", link, perl=TRUE)
    
    curlPerform(url=url, followLocation = TRUE, writedata=f@ref)
    
    close(f)
    invisible(NULL)
}
