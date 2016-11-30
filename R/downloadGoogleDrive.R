#' Download a file or folder specified by a google drive shared link.
#'
#' An email from a user via Google Drive offering a file or folder for
#' sharing includes a URL to that item and requires no further
#' credentials.  This URL is downloaded recursively into a directory
#' using the gdrive command-line client (see references).
#'
#' @param link URL of file on drive.google.com
#'
#' @param dir directory into which the file(s) will be downloaded
#'
#' @return stdout and stderr from running \code{gdrive}
#'
#' @references \url{https://github.com/prasmussen/gdrive}
#'
#' @references \url{https://developers.google.com/drive/v3/web/about-sdk}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

downloadGoogleDrive = function(link, dir) {

    ## URL from email looks like
    ## e.g. https://drive.google.com/folderview?id=0B483BNeq2WIsdXZDde78dDA
    ## or   https://drive.google.com/open?id=3D0B-bl0wWafEk1F1Y0hMdGZJQkk
    ## or   https://drive.google.com/file/d/0Bx3KaXOwqMcBU1NfMTlOSHFUVm8/view?usp=drive_web
    ## or   https://drive.google.com/drive/folders/0B-bl0wW8KbDxb2FQc3kwLU5YQnc?usp=sharing
    ##
    ## in each case, we extract the ID and determine whether it's to a folder or to a file

    x = parse_url(link)

    ## the id might be in the query
    ID = x$query$id

    if (is.null(ID)) {
        ## or it might be in the path
        ID = regexPieces("(?:(?:file/[[:alnum:]]+)|(?:drive/folders))/(?<id>[^?&\\\\]+)", x$path)[[1]]["id"][1]
        if (is.na(ID))
            return(invisible(NULL))
    }

    info = safeSys("gdrive", "info", ID, splitOutput=TRUE)

    ## gdrive sends errors to stdout, not stderr
    if (grepl("error", info[1], ignore.case=TRUE))
        stop("Unable to download file.\nAttempt to get metadata failed with: ", info[1])

    ## see whether it's a folder
    isdir = any(info == "Mime: application/vnd.google-apps.folder")

    rv = if (isdir) {
        safeSys("gdrive",
                "download",
                "query",
                "-r",
                "--no-progress",
                "--path",
                dir,
                paste0("\"'", ID, "' in parents\"")
                )
    } else {
        safeSys("gdrive",
                "download",
                "--no-progress",
                "--path",
                dir,
                ID
                )
    }
    ## sanitize download message
    rv = sub("Downloaded ([^ ]{6})[^ ]+ ", "Downloaded \\1... ", rv, fixed=TRUE)
    return(rv)
}
