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
#' @return a boolean vector of the same length as \code{src}, with TRUE
#' entries corresponding to files moved successfully.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

moveFilesUniquely = function(src, dst) {
    fd = basename(src)
    existing = dir(dst)

    ## regex to find possible "-NNN" suffixes on files
    nameRegex = "(?sx)^(?<base>.*)(-(?<number>[0-9]+)?)$"

    ## function to increment the -NNN extension (if any) on a file
    bumpSuffix = function(p) {
        if ("number" %in% names(p)) {
            paste0(p["base"], "-", 1+as.numeric(p["number"]))
        } else {
            paste0(p["base"], "-1")
        }
    }

    ## loop until no filename conflicts (ugly way to bump up -NNN suffixes)
    ## until there's no duplicate
    repeat {
        conflict = fd %in% existing | duplicated(fd)
        if (! any(conflict))
            break

        ## match portions of conflicting filenames
        parts = regexPieces(nameRegex, fd[conflict])

        ## rename according to rules

        fd[conflict] = lapply(parts, bumpSuffix)
    }
    file.rename(src, file.path(dst, fd))
}
