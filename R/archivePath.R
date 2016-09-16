#' Move a file or folder to a new location, ensuring it has a timestamped name.
#'
#' Some files such as SG system logs and unhandled files are stored
#' into folders, possibly for later manual processing.
#'
#' @param path vector of paths of files to save, or a scalar path to a
#'     folder to be saved.  If this is a folder whose name already begins
#'     with a timestamp, it is simply moved to \code{newdir}
#'
#' @param newdir directory in which to create a timestamped folder which will
#' hold \code{path} (if it's a file) or the contents of \code{path}, if it's a folder.
#' The directory \code{newdir} is created, if necessary.
#'
#' i.e.
#'
#'   myfile  -> newdir/YYYY-MM-DDTHH-MM-SS.SSSSSS/myfile      ## when \code{path} is a file
#'   mydir/* -> newdir/YYYY-MM-DDTHH-MM-SS.SSSSSS_mydir/*     ## when \code{path} is a folder
#'
#' or, when \code{path} is a folder whose name begins with a timestamp:
#' 
#'   2016-07-30T02-12-23.123455_mystuff/* -> newdir/2016-07-30T02-12-23.123455_mystuff/*
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

    recvdir = file.path(newdir, format(Sys.time(), MOTUS_TIMESTAMP_FORMAT))
    if (length(path) == 1 && file.info(path)$isdir) {
        if (grepl(MOTUS_LEADING_TIMESTAMP_REGEX, basename(path), perl=TRUE)) {
            file.rename(path, file.path(newdir, basename(path)))
            return (TRUE)
        }
        recvdir = paste0(recvdir, "_", basename(path))
        dir.create(dirname(recvdir), recursive=TRUE) ## ensure parent dirs exist
        file.rename(path, recvdir)
    } else {
        dir.create(dirname(recvdir), recursive=TRUE) ## create new dir
        file.rename(path, file.path(recvdir, basename(path)))  ## move file(s)
    }
    TRUE
}
