#' Test files for validity.
#'
#' Sometimes users send shared links to folders before all files have sync'd,
#' so these files might not be valid when downloaded.
#'
#' @param files vector of paths of files to check
#'
#' @return integer vector of same length as \code{files}, with values
#' from this list:
#'
#' \enumerate{
#' \item if the file passes all tests
#' \item if the file doesn't exist
#' \item if the file is non-empty but all zeroes
#' \item if the file has a .gz, .bz2, .7z, .rar, or .zip extension, but fails
#' the integrity test of the appropriate archiving program
#' }
#'
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

testFile = function(files) {
    rv = rep(0L, length(files))
    fi = file.info(files)
    for (i in seq(along=files)) {
        ec = safeSys("cmp", "/dev/zero", files[i], minErrorCode=3)
        if (is.na(fi$size[i])) {
            rv[i] = 1   ## file doesn't exist
            next
        }
        if (fi$size[i] > 0 && ec == "") {
            rv[i] = 2;  ## file is all zeroes, but non-empty
            next
        }
        if (grepl("\\.(bz2|gz|zip|7z)$", files[i], ignore.case=TRUE)) {
            ec = attr(safeSys("7zip", "t", files[i], minErrorCode=255), "exitCode")
            if (ec != 0) {
                rv[i] = 3;  ## file is corrupt archive
                next
            }
        } else if (grepl("\\.rar$", files[i], ignore.case=TRUE)) {
            ec = attr(safeSys("unrar", "t", files[i], minErrorCode=255), "exitCode")
            if (ec != 0) {
                rv[i] = 3;  ## file is corrupt archive
                next
            }
        }
    }
    return(rv)
}