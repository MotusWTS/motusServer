#' return the contents of a text file as a character scalar, or the
#' empty string if the file doesn't exist.
#'
#' @param f full path to the file
#'
#' @return character scalar with the file contents, or empty if the file is empty
#' or doesn't exist.
#'
#' @note mainly for reading a file which is not known to exist, e.g. a file whose name
#' is passed as a parameter to a sub-shell, but where there's no guarantee the subshell
#' actually wrote to it.
#'
#' Contents only up to the first embedded NUL are returned.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

textFileContents = function(f) {
    tryCatch(
        return (suppressWarnings(readChar(f, file.size(f), useBytes = TRUE)))
        , error = function(e) {
            return ("")
        })
}

