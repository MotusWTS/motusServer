#' Download files from an FTP site.
#'
#' Recursively downloads all files from the specified URL.
#' The permitted file suffixes and maximum recursion depth can be set to protect
#' against accidentally downloading far more than was intended.
#'
#' @param link URL of an FTP location.  If the site is password protected, the URL
#' must contain a \code{USER:PASSWORD@} portion (see the example)
#'
#' @param dir directory into which the file(s) will be downloaded
#'
#' @param suffixes vector of file types (by suffix) to download.
#' Defaults to \code{c(".gz", ".txt", ".zip", ".7z")}.
#'
#' @param maxDepth maximum depth of nested folders to download, starting
#' at \code{URL}.  Default: 5.
#' 
#' @return returns invisible(NULL)
#'
#' @examples
#'
#' ## download.FTP("ftp://USER:PASSWD@ftp.depot.qc.ec.gc.ca/depot/SG/Mai2016/BBBK0489_Estimauville")
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

download.FTP = function(link, dir, suffixes=c(".gz", ".txt", ".zip", ".7z", ".rar", ".ZIP", ".7Z", ".TXT", ".RAR", ".GZ"), maxDepth=5) {

    safeSys("wget",
            "--quiet",
            "--directory-prefix",
            dir,
            "--accept",
            paste(suffixes, collapse=","),
            "--level",
            maxDepth,
            "--recursive",
            "--no-host-directories",
            link
            )
    invisible(NULL)
}
