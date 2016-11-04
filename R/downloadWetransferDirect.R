#' Download a file specified by a direct wetransfer.com link.
#'
#' The email sent from wetransfer.com to a file recipient contains a
#' direct link to the downloadable file.  That file is downloaded
#' into the specified directory.
#'
#' @param link URL of file on wetransfer.com, from email sent to the file
#' recipient.
#'
#' @param dir directory into which the file(s) will be downloaded
#'
#' @return character scalar saying how many bytes were downloaded.  It has
#' these attributes:
#' \itemize{
#' \item \code{fileName} name of the downloaded file
#' \item \code{hashName} security-hash version of the downloaded file's
#' name, e.g. "wetransfer-ab2de9.zip"  When multiple files are sent in
#' a single transfer, \code{fileName==hashName}.  The hashName is
#' convenient for recording which downloads have been made.
#' }
#'
#' @note wetransfer.com does not have a published download API, so we
#'     do this the tedious way, by parsing responses from their
#'     server.  Watch for changes to the format of emails and server
#'     replies that might break this fragile code.
#'
#' @seealso \link{\code{download.wetransferConf}} for downloading using
#' the link in a confirmation email to the file sender.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

downloadWetransferDirect = function(link, dir) {

    ## URL from email looks like
    ## e.g. "https://www.wetransfer.com/downloads/cd322a32324cb041abb0968a3d4de0da20160104173429/f501a0c6e883c472e550f8cba4bbadcb20160104173429/7de1e5

    parts = strsplit(link, "/", fixed=TRUE)[[1]]

    url = sprintf("https://www.wetransfer.com/api/v1/transfers/%s/download?recipient_id=%s&security_hash=%s&password=&ie=false",
                  parts[5], parts[6], parts[7])

    ## check whether file has already been manually downloaded using the security hash
    hashName = paste0("wetransfer-", parts[7])
    dl = file.path(MOTUS_PATH$DOWNLOADS, hashName)
    oldf = dir(dl, full.names=TRUE)
    if (length(oldf) > 0) {
        inf = file.info(oldf)
        if (inf$size > 0) {
            if (dir != MOTUS_PATH$DOWNLOADS) {
                moveFiles(oldf, dir)
                unlink(dl) ## remove the cache
            }
            return(structure(paste("Used file with size", inf$size, "bytes already downloaded on ", inf$ctime),
                             fileName = oldf,
                             hashName = hashName))
        }
        ## drop empty bogus previous download
        unlink(dl, recursive=TRUE)
    }

    ## get rewritten URL from wetransfer.com
    resp = fromJSON(getURLContent(url, followlocation=TRUE))

    ## might or might not contain a direct_link field; process appropriately
    if ("direct_link" %in% names(resp)) {
        p = parse_url(resp$direct_link)
        file = p$query$filename
        if (is.null(file))
            file = basename(p$path)
        if (! isTRUE(nchar(file) > 0)) {
            file = basename(tempfile())
        } else {
            ## sanitize to protect against malicious filenames
            file = sub("[/~]", "", file, perl=TRUE)
        }
        file = file.path(dir, file)
        f = CFILE(file, "wb")
        curlPerform(url=resp$direct_link, writedata=f@ref)
        RCurl::close(f)
    } else {
        file = resp$fields$filename
        if (! isTRUE(nchar(file) > 0)) {
            ## another possible location for the filename
            file = basename(resp$formdata$action)
            if (! isTRUE(nchar(file) > 0)) {
                file = basename(tempfile())
            }
        } else {
            file = sub("[/~]", "", file, perl=TRUE)
        }
        file = file.path(dir, file)
        f = CFILE(file, "wb")
        ## awkward assembly of query:
        curlPerform(url=paste0(resp$formdata$action,'?', paste0(names(resp$fields), '=', curlEscape(resp$fields), collapse="&")), writedata=f@ref)
        RCurl::close(f)
    }
    return(structure(paste("Downloaded", file.info(file)$size, "bytes"),
                     fileName = file,
                     hashName = hashName
                     ))
}
