#' Rerun an upload job, after some external error condition has been fixed.
#'
#' @param j the job, as an integer scalar job number. This can be a
#'     top-level job, or one of its sub-jobs; in the latter case, the
#'     top-level job is used anyway.  The top-level job must be of
#'     type "uploadFile", otherwise this function throws an error.
#'
#' @details
#' First, this removes all traces of the original upload job, both from the
#' job database, and the filesystem:
#' \itemize{
#' \item{all jobs in server.sqlite with \code{stump == j}}
#' \item{the folder at \code{j$path}}
#' \item{any files \code{/sgm/errors/NNNNNNNN.rds} where \code{stump(NNNNNNNN) == j}}
#' }
#'
#' Then, a new hardlink to the original uploaded file is created in
#' \code{/sgm/uploads}.  The original uploaded file is recorded in
#' \code{j$filename}, or as \code{sj$file} where \code{sj} is a subjob
#' of \code{j} with type "unpackArchive").
#'
#' This will cause the uploadServer to re-queue the
#' originally-uploaded file.
#'
#' @note this function does not revert any changes to receiver
#'     databases affected by the original processing of the uploaded
#'     file.
#'
#' @return TRUE if the job was found, of the correct type and
#'     resubmitted to the uploadServer; FALSE otherwise.
#'
#' @seealso \code{\link{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

rerunUploadJob = function(j) {
    if (is.numeric(j))
        j = Jobs[[j]]
    j = topJob(j)

    if (is.null(j)) {
        warning("invalid job number")
        return(FALSE)
    }

    if (j$type != "uploadFile") {
        warning("job is not of type 'uploadFile'")
        return(FALSE)
    }

    filename = j$filename
    if (is.null(filename)) {
        filename = Jobs[stump==R(j) & type=="unpackArchive"]$file
        if (is.null(filename)) {
            warning("unable to determine uploaded filename: not in j$filename or sj$file for sj a subjob of type 'unpackArchive'")
            return(FALSE)
        }
        filename = basename(filename)
    }

    ## make sure uploaded file can still be found, before deleting anything
    parts = strsplit(filename, ":")
    uid = parts[[1]][1]

    uploadFile = file.path(MOTUS_PATH$UPLOAD_ARCHIVE, uid, filename)
    if (!file.exists(uploadFile)) {
        warning("unable to locate uploaded file; expected it to be here: ", uploadFile)
        return(FALSE)
    }

    errIDs = Jobs[stump==R(j) & done < 0]
    file.remove(file.path(MOTUS_PATH$ERRORS, sprintf("%08d.rds", errIDs)))
    unlink(j$path, recursive=TRUE)
    ServerDB(sprintf("delete from jobs where stump=%d", j))
    motusLog("Deleted records and folders of job %d and its subjobs", j)

    file.link(uploadFile, file.path(MOTUS_PATH$UPLOADS, basename(uploadFile)))
    motusLog("Created new hardlink to %s in %s", uploadFile, MOTUS_PATH$UPLOADS)

    return(TRUE)
}
