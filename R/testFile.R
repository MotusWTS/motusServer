#' Test files for validity.
#'
#' Sometimes users send shared links to folders before all files have sync'd,
#' so these files might not be valid when downloaded.
#'
#' @param files vector of paths of files to check
#'
#' @param tests integer vector of tests to try; must be a subset of 1:4.
#' Alternatively, this can be a list, in which case element \code{tests[[i]]} is
#' an integer vector specifying the tests to be performed on the \code{i}th file.
#' Default: 1:4
#'
#' @return integer vector of same length as \code{files}, with values
#' from this list:
#'
#' \itemize{
#' \item 0: the file passes all tests
#' \item 1: the file doesn't exist
#' \item 2: the file is empty.
#' \item 3: the file is non-empty but all zeroes
#' \item 4: the file is non-empty and has a .gz, .bz2, .7z, .rar, or .zip extension, but fails
#' the integrity test of the appropriate archiving program
#' }
#' For each input file, the function returns either 0, or the number of the
#' first test to fail.  Tests are attempted in order of increasing number.
#'
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

testFile = function(files, tests=1:4) {
    if (! is.list(tests))
        tests = rep(list(tests), length(files))
    rv = rep(0L, length(files))
    fi = file.info(files)
    for (i in seq(along=files)) {
        if (1L %in% tests[[i]] && is.na(fi$size[i])) {
            rv[i] = 1L   ## file doesn't exist
            next
        }
        if (2L %in% tests[[i]] && fi$size[i] == 0) {
            rv[i] = 2L
            next
        }
        if (3L %in% tests[[i]]) {
            ec = safeSys("cmp", "/dev/zero", files[i], minErrorCode=3)
            if (ec == "") {
                rv[i] = 3L;  ## file is all zeroes
                next
            }
        }
        if (4L %in% tests[[i]]) {
            if (grepl("\\.(bz2|zip|7z)$", files[i], ignore.case=TRUE)) {
                ## for these files, we use 7z's "l" command, not "t", as the
                ## latter recursively tests files within archives, which we don't
                ## want to do.
                ec = attr(safeSys("7z", "l", files[i], minErrorCode=255), "exitCode")
                if (ec != 0) {
                    rv[i] = 4L;  ## file is corrupt archive
                    next
                }
            } else if (grepl("\\.gz$", files[i], ignore.case=TRUE)) {
                ec = attr(safeSys("gzip", "-t", files[i], minErrorCode=255), "exitCode")
                if (ec != 0) {
                    rv[i] = 4L;  ## file is corrupt archive
                    next
                }
            } else if (grepl("\\.rar$", files[i], ignore.case=TRUE)) {
                ec = attr(safeSys("unrar", "t", files[i], minErrorCode=255), "exitCode")
                if (ec != 0) {
                    rv[i] = 4L;  ## file is corrupt archive
                    next
                }
            }
        }
    }
    return(rv)
}
