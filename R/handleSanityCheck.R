#' Do basic sanity checks on all files (recursively0 in a folder.
#'
#' Files are checked with testFile.  Any files which fail the
#' test are archived into the file badfiles.zip.NOAUTO in the
#' folder for the top job, and then deleted.
#'
#' If any files fail sanity checks, summary messages are written to
#' the job log.
#'
#' @param j the subjob, which has parameters:
#' \itemize{
#' \item dir: path to the folder to be checked
#' }
#' @return TRUE if all files pass; FALSE otherwise
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleSanityCheck = function(j) {
    t = topJob(j)
    f = dir(j$dir, recursive=TRUE, full.names=TRUE)
    chk = testFile(f)
    if (all(chk == 0))
        return(TRUE)
    ch2 = f[chk == 2]; ## zero-filled files
    if (length(ch2) > 0) {
        jobLog(j, c(paste("Error: these", length(ch2), "files are full of zeroes:"),
                    "(perhaps your folder has not finished syncing?)",
                    paste0("   ", basename(head(ch2, 5))), if (length(ch2) > 5) "   ..."))
    }
    ch3 = f[chk == 3]; ## corrupt archives
    if (length(ch3) > 0) {
        jobLog(j, c(paste("Error: these", length(ch3), "archives are corrupt:"),
                    "(perhaps your folder has not finished syncing?)", paste0("   ", basename(ch3))))
    }
    if (any(chk == 0)) {
        jobLog(j, paste("Processing will continue with the remaining", sum(chk==0), "files."))
    }
    ## write names of bad files to a temporary location so we can tar them;
    ## to prevent collisions from different archives with same-named files,
    ## we prepend the job ID

    tmpf = tempfile()
    writeLines(f[chk > 0], tmpf)

    ## append files to a zip archive, using the file-list mechanism
    rv = safeSys(paste0("cd ", j$dir, "/..; cat ", tmpf, " | zip -@ ", file.path(t$path, MOTUS_BADFILE_ARCHIVE)), quote=FALSE)

    ## drop file list
    file.remove(tmpf)

    ## if compression succeeded, delete bad files, which have now been archived
    if (attr(rv, "exitCode") == 0)
        file.remove(f[chk > 0])
    return (TRUE)
}
