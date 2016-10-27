#' Try unpack a compressed archive into its job folder.
#'
#' @param j the job, which has this parameter:
#' \itemize{
#' \item file: the path to the archive file
#' }
#'
#' @return TRUE on success; FALSE otherwise
#'
#' @note if successfull, new subjobs to run sanity checks and unpack nested
#' archives are queued.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleUnpackArchive = function(j) {
    file = j$file
    bn = basename(file)
    dir = j$path

    suffix = regexPieces(MOTUS_ARCHIVE_REGEX, bn)[[1]] %>% tolower

    cmd = NULL
    if (isTRUE(length(suffix) > 0)) {
        cmd = switch(suffix,
                     "zip" = "unzip",
                     "7z"  = "7z x",
                     "rar" = "unrar",
                     NULL)
    }

    if (is.null(cmd)) {
        jobLog(j, paste0("Unknown compression suffix on file ", bn,
               "Must be .zip, .7z, or .rar"))
        return (FALSE)
    }
    jobLog(j, paste0("Unpacking file ", bn, " with ", paste(cmd, collapse=" ")))
    res = safeSys("cd", dir, ";", cmd, file, shell=TRUE, splitOutput=TRUE)
    jobLog(j, c(head(res, 3), "...", tail(res, 3)))
    file.remove(file)

    newSubJob(j, "sanityCheck", dir=dir)
    newSubJob(j, "queueArchives", dir=dir)

    return (TRUE)
}
