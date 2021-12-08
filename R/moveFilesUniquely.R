#' Move files to a single folder, renaming new files in cases
#' of conflict.
#'
#' @details
#'
#' Filenames that conflict with each other or those already in
#' \code{dst} are changed like so:
#'
#' \enumerate{
#' \item if the filename does not end in \code{-NNN}  where \code{NNN} is an
#' integer, then add \code{-1} to
#' the filename; e.g.
#'
#'    \code{myfile.txt -> myfile.txt-1}
#'
#' \item if the filename already ends in \code{-NNN}, then
#' increment \code{NNN}; e.g.
#'
#'   \code{myfile.txt-3 -> myfile.txt-4}
#'
#' }
#'
#' @param src character vector of full paths of files to move
#'
#' @param dst path to target folder
#'
#' @param copyLinkTargets logical: if TRUE, when an item in `src` is a symbolic
#' link, it is replaced with a copy of the target of the link, and it is that copy which is moved to `dst`,
#' rather than just the symlink itself.
#' Default: FALSE (it is the symlink itself which is moved, not the file it points to).
#'
#' @return a character vector of the same length as \code{src}, with non-NA
#' entries giving new names for any files that were renamed
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

moveFilesUniquely = function(src, dst, copyLinkTargets=FALSE) {
    if (length(src) == 0)
        return(character(0))

    fname = basename(src)
    existing = dir(dst)

    ## regex to find possible "-NNN" suffixes on files
    nameRegex = "(?sx)^(?:(?:(?<base>.*)-(?<number>[0-9]+))$)|(?<base2>.*)$"

    ## function to increment the -NNN extension (if any) on a file
    bumpSuffix = function(p) {
        if ("number" %in% names(p)) {
            paste0(p["base"], "-", 1+as.numeric(p["number"]))
        } else {
            paste0(p["base2"], "-1")
        }
    }

    ## loop until no filename conflicts (ugly way to bump up -NNN suffixes)
    ## until there's no duplicate
    initial.conflict = NULL
    repeat {
        conflict = fname %in% existing | duplicated(fname)
        if (is.null(initial.conflict))
            initial.conflict = conflict
        if (! any(conflict))
            break

        ## match portions of conflicting filenames
        parts = regexPieces(nameRegex, fname[conflict])

        ## rename according to rules

        fname[conflict] = sapply(parts, bumpSuffix)
    }
    success = logical(length(src)) ## booleans indicating success per file
    if(copyLinkTargets) {
        targ = Sys.readlink(src)
        iTarg = which(isTRUE(nchar(targ) > 0)) ## only files which are valid symlinks pass this test
        if(length(iTarg)) {
            ## use rename where possible
            success[!iTarg] = file.rename(src[!iTarg], file.path(dst[!iTarg], fname[!iTarg]))
            ## otherwise copy
            success[iTarg] = file.copy(src[iTarg], file.path(dst[iTarg], fname[iTarg]))
            ## only delete the original file where the copy succeeded
            file.remove(src[iTarg][success[iTarg])
        } else {
            success = file.rename(src, file.path(dst, fname))
        }
    } else {
        success = file.rename(src, file.path(dst, fname))
    }
    if(any(!success)) {
        stop(paste("In moveFilesUniquely, failed to successfully move:", src[!success]))
    }
    return(ifelse(initial.conflict, fname, NA))
}
