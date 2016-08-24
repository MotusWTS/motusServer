#!/usr/bin/Rscript

._(` (

   getWeTransferFile.R

Download a file from wetransfer.com, given a URL obtained
from an email.

Call this script as so:

  getWeTransferFile.R URL


._(` )

ARGS = commandArgs(TRUE)
Lib = function(x) library(x, character.only=TRUE, verbose=FALSE, quietly=TRUE)
Lib("jsonlite")
Lib("RCurl")
Lib("httr")

if (length(ARGS) != 1) {
  ._SHOW_INFO()
  quit(save="no")
}

EMAILURL = ARGS[1]

cat("Grabbing: ", EMAILURL, "\n")

if (grepl("https://we.tl", EMAILURL)) {
    x = getURL(EMAILURL)
    ## reformat the returned URL:
    ## e.g.
    ## "https://www.wetransfer.com/downloads/f577d5d876d271e0228ac28e2cfd502f20160420213117/6acdc8"
    ## ->
    ## "https://api.wetransfer.com/api/v1/transfers/f577d5d876d271e0228ac28e2cfd502f20160420213117/download?recipient_id=&security_hash=6acdc8&password=&ie=false&ts=1461204325054"
    parts = strsplit(x$url, "/", fixed=TRUE)[[1]]
    options(digits=14) ## for getting timestamp as integer
    newURL = sprintf("https://api.wetransfer.com/api/v1/transfers/%s/download?recipient_id=&security_hash=%s&password&ie=false&ts=%g",
                     parts[5],
                     parts[6],
                     round(as.numeric(Sys.time()) * 1000)
                     )
    y = getURL(newURL, set_cookies(unlist(x$cookies[2])))
    directLink = fromJSON(rawToChar(y$content))$direct_link
    file = parse_url(directLink)$query$filename
    x = getURL(directLink)
} else {
    ## URL from email looks like
    ## e.g. "https://www.wetransfer.com/downloads/cd322a32324cb041abb0968a3d4de0da20160104173429/f501a0c6e883c472e550f8cba4bbadcb20160104173429/7de1e5

    parts = strsplit(EMAILURL, "/", fixed=TRUE)[[1]]

    url = sprintf("https://www.wetransfer.com/api/v1/transfers/%s/download?recipient_id=%s&security_hash=%s&password=&ie=false",
                  parts[5], parts[6], parts[7])

    ## get rewritten URL from wetransfer.com
    resp = fromJSON(getURLContent(url, followlocation=TRUE))

    ## might or might not contain a direct_link field; process appropriately
    if ("direct_link" %in% names(resp)) {
        p = parse_url(resp$direct_link)
        file = p$query$filename
        if (is.null(file))
            file = basename(p$path)
        if (! isTRUE(nchar(file) > 0))
            file = tempfile(tmpdir=".")
        file = sub("[/~]", "", file, perl=TRUE)
        f = CFILE(file, "wb")
        curlPerform(url=resp$direct_link, writedata=f@ref)
        close(f)
    } else {
        file = resp$fields$filename
        if (! isTRUE(nchar(file) > 0))
            file = tempfile(tmpdir=".")
        f = CFILE(file, "wb")
        ## awkward assembly of query:
        curlPerform(url=paste0(resp$formdata$action,'?', paste0(names(resp$fields), '=', curlEscape(resp$fields), collapse="&")), writedata=f@ref)
        close(f)
    }
    cat("Wrote ", file.info(file)$size, " bytes to ", file, "\n")
    cat(format(Sys.time()), " ", EMAILURL, "\n", file=file("/sgm/logs/wetransferlog.txt", "a"))
}
