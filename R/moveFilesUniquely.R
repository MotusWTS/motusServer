#' Move files from one folder to another, renaming new files in cases
#' of conflict.
#'
#' @details
#' Filenames that conflict with those already in \code{dest} are changed
#' like so:
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
#' @param src path to source folder
#'
#' @param dest path to target folder
#'
#' @return a boolean vector of the same length as \code{dir(src)}, with TRUE 
#' entries corresponding to files moved successfully.
#'
#' @note Why not just use \code{"/bin/cp --backup"}?  Because we want
#'     stability in filenames in the receiver DB, earlier files with a
#'     given name should take precendence.  Standard linux tools
#'     (e.g. \code{rsync, cp, mv, install}) all seem to give precedence
#'     to new files, renaming existing ones of the same name.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

moveFilesUniquely = function(src, dest) {
    fs = fd = dir(src)
    conflict = fs %in% dir(dest)
    if (sum(conflict) > 0) {

        ## match portions of conflicting filenames
        parts = regexPieces("(?sx)
            ^
            (?:(?<base>.*)-(?<number>[0-9]+)(?<ext>\\.[^.]*))
              |
            (?:(?<base2>.*)(?<ext2>\\.[^.]*))
            $",
            fs[conflict])

        ## rename according to rules

        fd[conflict] = lapply(parts,
                      function(p) {
                          if ("ext2" %in% names(p)) {
                              paste0(p["base2"], "-1", p["ext2"])
                          } else {
                              paste0(p["base"], "-", as.integer(p["number"]) + 1, p["ext"])
                          }
                      }
                      )
    }
    file.rename(file.path(src, fs), file.path(dest, fd))
}
