#' Queue a new sub-job for each archive in a folder.
#'
#' For each .7z, .zip, and .rar file, a subjob is queued which
#' will unpack the archive.
#'
#' @param j the job with item:
#' \itemize{
#' \item dir directory in which to search (recursively) for archives
#' }
#'
#' @return no return value
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleQueueArchives = function(j) {
    archs = dir(j$dir, recursive=TRUE, pattern=".*zip|.*7z|.*rar", ignore.case=TRUE,
                full.names=TRUE)
    for (a in archs) {
        newSubJob(j, "unpackArchive", path=j$path, file=a)
    }
}
