#' handle a folder of files from the server
#'
#' Called by \code{\link{processServer}}.  Any files in subfolders
#' of the specified job's folder are processed.  These might be archives
#' that need to be sanity checked and unpacked.
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

handleServerFiles = function(j) {

    path = jobPath(j)

    ## queue a job to sanity check the files
    newSubJob(j, "sanityCheck", dir=path)

    ## queue a job to unpack archives
    newSubJob(j, "queueArchives", dir=path)

    ## queue a job to finally handle all the files
    newSubJob(j, "newFiles")

    return (TRUE)
}
