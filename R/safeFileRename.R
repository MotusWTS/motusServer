#' rename files, even across filesystems
#'
#' drop-in replacement for file.rename that correctly handles
#' renames across filesystems on linux
#' - copies the file from filesystem A to filesystem B
#' - only if the copy succeeded, delete the file from filesystem B
#'
#' @param from character vector giving filename or path
#'
#' @param to character vector giving filename or path
#'
#' @return logical vector,\code{rv}, that is TRUE for each successful rename, FALSE elsewhere
#'
#' Upon returning:
#' \itemize{
#'    \item the files `from[rv]` no longer exist, and their contents are now stored in files `to[rv]`.
#'    \item the files `from[! rv]` and `to[! rv]` are preserved, if they already existed, and
#' are not created if they didn't already exist.
#' }
#' i.e. unsuccesful renaming leaves source and destination items as they were.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

safeFileRename = function(from, to) {
    if (.Platform$OS.type != "unix")
        return (file.rename(from, to))
    if (length(from) != length(to))
        stop("need same length for from, to")
    src = data.frame(name=from, dirname=dirname(from))
    dst = data.frame(name=to,   dirname=dirname(to))

    ## get device number each directory resides on; requires that sum of path lengths of unique top-level directories
    ## don't exceed the shell's command-line buffer

    try({
        devNo = function(x) system(paste0("stat -c '%d' ", paste0('"', x, '"', collapse=" ")), intern=TRUE)

        levels(src$dirname) = devNo(levels(src$dirname))
        levels(dst$dirname) = devNo(levels(dst$dirname))
    }, error = function(e) {
        stop(paste0("safeFileRename has failed with the message:\n", e$message, "\nOften this is because an archive with too many files was uploaded. Try uploading the files for one receiver at a time."))
    })

    ## which src, dst pairs are on the same filesystem?
    samefs = as.character(src$dirname) == as.character(dst$dirname)

    ## return value is a logical vector indicating success per file
    rv = logical(length(from))

    ## use rename where possible, copy otherwise
    rv[  samefs] = file.rename(from[  samefs], to[  samefs])
    rv[! samefs] = file.copy  (from[! samefs], to[! samefs], overwrite=TRUE)
    ## only delete files where the copy succeeded
    file.remove(from[! samefs][rv[! samefs]])
    return(rv)
}
