#' Move files to a single folder, renaming new files in cases
#' of conflict.
#'
#' @details
#'
#' Filenames that conflict with each other or those already in
#' \code{dst} are changed like so:
#'
#' \enumerate{
#' \item if the filename does not end in \code{-NNN.EXT}  where \code{NNN} is an
#' integer and \code{EXT} is the file extension, then add \code{-1} to
#' the filename before the extension; e.g.
#'
#'    \code{myfile.txt -> myfile-1.txt}
#'
#' \item if the filename already ends in \code{-NNN.EXT}, then
#' increment \code{NNN}; e.g.
#'
#'   \code{myfile-3.txt -> myfile-4.txt}
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

moveFilesUniquely = function(src, dst, ...) {
    fd = basename(src)
    existing = dir(dst)

    ## regex to match file extensions, including added "-NNN"
    nameRegex = "(?sx)
            ^
            (?:(?<base>.*)-(?<number>[0-9]+)(?<ext>\\.[^.]*))
              |
            (?:(?<base2>.*)(?<ext2>\\.[^.]*))
            $"

    ## function to increment the -NNN extension (if any) on a file
    bumpSuffix = function(p) {
        if ("ext2" %in% names(p)) {
            paste0(p["base2"], "-1", p["ext2"])
        } else {
            paste0(p["base"], "-", as.integer(p["number"]) + 1, p["ext"])
        }
    }

    ## loop until no filename conflicts
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
