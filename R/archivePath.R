#' Save a file or folder in a timestamped location.
#'
#' Some files such as SG system logs and unhandled files are stored
#' into folders, possibly for later manual processing.
#'
#' @param path file or folder to be saved
#'
#' @param newdir directory in which to create a timestamped folder which will
#' hold \code{path} (if it's a file) or the contents of \code{path}, if it's a folder.
#' The directory \code{newdir} is created, if necessary.
#'
#' i.e.
#'
#'   myfile  -> newdir/YYYY-MM-DDTHH-MM-SS/myfile      ## when \code{path} is a file
#'   mydir/* -> newdir/YYYY-MM-DDTHH-MM-SS_mydir/*     ## when \code{path} is a folder
#'
#' This means the basename of \code{path} is preserved, either as the
#' destination filename, or as part of the destination folder name.
#' This makes it easier to trace the origin of the folder from the
#' server mainlog.
#'
#' @return TRUE iff the file or folder was successfully archived
#'
#' @export
#'
#' @seealso \link{\code{server}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

archivePath = function(path, newdir) {

    recvdir = file.path(recvdir, format(Sys.time(), "%Y-%m-%dT%H-%M-%S"))
    if (file.info(path)$isdir) {
        recvdir = paste0(recvdir, "_", basename(path))
        dir.create(dirname(recvdir), recursive=TRUE) ## ensure parent dirs exist
        file.rename(path, recvdir)
    } else {
        dir.create(dirname(recvdir), recursive=TRUE) ## create new dir
        file.rename(path, file.path(recvdir, basename(path)))  ## move file
    }
}
