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
#' \itemize{
#' \item 0: the file passes all tests
#' \item 1: the file doesn't exist
#' \item 2: the file is non-empty but all zeroes
#' \item 3: the file is non-empty and has a .gz, .bz2, .7z, .rar, or .zip extension, but fails
#' the integrity test of the appropriate archiving program
#' \item 4: the file is empty.
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
        if (fi$size[i] == 0) {
            rv[i] = 4
            next
        }
        if (ec == "") {
            rv[i] = 2;  ## file is all zeroes
            next
        }
        if (grepl("\\.(bz2|gz|zip|7z)$", files[i], ignore.case=TRUE)) {
            ec = attr(safeSys("7z", "l", files[i], minErrorCode=255), "exitCode")
            if (ec != 0) {
                ## a .gz archive can be corrupt because the SG hasn't finished writing it out
                ## yet; the evidence for this will be existince of a file with the same name but
                ## without the .gz ending; we check for this, and don't mark the file as
                ## corrupt in this situation. In principle, we could just leave it out,
                ## but downstream code is set up to handle this, so we just let it do so.

                if ( (! grepl("\\.gz$", files[i], ignore.case=TRUE))
                    || (! file.exists(sub("\\.gz$", "", files[i], ignore.case=TRUE)))) {
                    rv[i] = 3;  ## file is corrupt archive
                }
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
