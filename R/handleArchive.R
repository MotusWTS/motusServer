#' handle a compressed archive.
#'
#' If possible the compressed archive is extracted into a temporary folder
#' which is then enqueued.
#'
#' @param path the full path to the file with the download link
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @return TRUE iff the archive \code{path} was succesfully extracted.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleArchive = function(path, isdir) {
    suffix = regexPieces(MOTUS_ARCHIVE_REGEXP, path)[[1]] %>% tolower

    if (isdir || length(suffix) == 0)
        return (FALSE)

    tmpdir = motusTempPath()

    cmd = switch(suffix,
                 "zip" = "unzip",
                 "7z"  = "7z x",
                 "rar" = "unrar",
                 NULL)
    if (is.null(cmd))
        return (FALSE)

    motusLog("Unpacking into %s with %s:  %s", tmpdir, cmd, path)
    if ( system(
        sprintf("cd %s;%s %s",
                tmpdir,
                cmd,
                shquote(path)
                )
    )) return (FALSE)  ## unpacking failed

    enqueue(path)

    return (TRUE)
}
