#' Try handle a compressed archive.
#'
#' If \code{path} is a compressed archive of known type, it is
#' extracted into a temporary folder which is then enqueued.
#'
#' @param path the full path to the file with the download link
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @return TRUE iff the \code{path} was an archive and succesfully extracted.
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleArchive = function(path, isdir) {
    suffix = regexPieces(MOTUS_ARCHIVE_REGEX, path)[[1]] %>% tolower

    if (isdir || length(suffix) == 0)
        return (FALSE)

    tmpdir = makeQueuePath()

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
                shQuote(path)
                )
    )) return (FALSE)  ## unpacking failed

    enqueue(tmpdir)

    return (TRUE)
}
