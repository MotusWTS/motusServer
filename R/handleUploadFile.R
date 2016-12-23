#' handle an uploaded file
#'
#' Called by \code{\link{processServer}}.  The file is sanity checked,
#' unpacked if necessary, then run.
#'
#' @param j the job
#'
#' @return  TRUE; As a side effect, subjobs for sanity checking files and
#' unpacking archives are queued.
#'
#' @seealso \code{\link{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleUploadFile = function(j) {

    path = jobPath(j)

    ## queue a job to sanity check the files
    newSubJob(j, "sanityCheck", dir=path)

    ## queue a job to unpack archives
    newSubJob(j, "queueArchives", dir=path)

    ## queue a job to finally handle all the files
    newSubJob(j, "newFiles")

    ## fixme: add a job to email the user upon job completion
    newSubJob(j, "uploadProcessed")

    return (TRUE)
}
