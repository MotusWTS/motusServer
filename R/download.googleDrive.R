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
#' @return returns invisible(NULL)
#'
#' @references \url{https://github.com/prasmussen/gdrive}
#'
#' @references \url{https://developers.google.com/drive/v3/web/about-sdk}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

download.googleDrive = function(link, dir) {

    ## URL from email looks like
    ## e.g. https://drive.google.com/folderview?id=0B483BNeq2WIsdXZDde78dDA

    x = parse_url(link)

    ## each file or folder has a unique ID
    ID = x$query$id

    info = readLines(pipe(paste("gdrive", "info", ID)))

    ## see whether it's a folder
    isdir = any(info == "Mime: application/vnd.google-apps.folder")

    if (isdir) {
        safeSys("gdrive",
                "download",
                "query",
                "--no-progress",
                "--path",
                dir,
                paste0("'", ID, "' in parents")
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
    invisible(NULL)
}
