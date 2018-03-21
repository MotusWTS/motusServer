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
    ## in case `j$file` has a stale queue component due to the job
    ## being retried on a new queue, fix it; see https://github.com/jbrzusto/motusServer#393

    file = sub(paste0("^", MOTUS_PATH$QUEUES, '[0-9]+'), file.path(MOTUS_PATH$QUEUES, MOTUS_PROCESS_NUM), perl=TRUE, j$file)

    bn = basename(file)
    dir = jobPath(j)

    suffix = regexPieces(MOTUS_ARCHIVE_REGEX, bn)[[1]] %>% tolower

    cmd = NULL
    ## generally, any error in unpacking should be propagated up the R stack
    minErrorCode = 1
    postopts = NULL
    if (isTRUE(length(suffix) > 0)) {
        cmd = switch(suffix,
                     "zip" = {postopts = c("-x", "/"); c("unzip", "-o")},       ## N.B.: put args in own strings
                     "7z"  = c("7z", "x", "-y"),

                     ## unar returns 1 on *any* error, even if due to a
                     ## contained .gz file having a problem, so we have to
                     ## use a different minErrorCode that effectively ignores
                     ## all errors, and hopes that lsar in handleSanityChecks
                     ## caught truly bogus .rar files
                     ## see https://github.com/jbrzusto/motusServer/issues/390

                     "rar" = {minErrorCode = 2; c("unar", "-f", "-nr")},
                     NULL)
    }

    if (is.null(cmd)) {
        jobLog(j, paste0("Unknown compression suffix on file ", bn,
               "Must be .zip, .7z, or .rar"))
        return (FALSE)
    }
    jobLog(j, paste0("Unpacking file ", bn, " with ", paste(cmd, collapse=" ")))
    res = safeSys("cd", dir, nq=";", cmd, file, postopts, shell=TRUE, splitOutput=TRUE)
    jobLog(j, c(head(res, 3), "...", tail(res, 3)))
    file.remove(file)

    newSubJob(j, "sanityCheck", dir=dir)
    newSubJob(j, "queueArchives", dir=dir)

    return (TRUE)
}
