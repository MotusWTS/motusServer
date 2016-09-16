#' handle a single file or folder
#'
#' Called by \code{\link{server}} for a file or folder added
#' to the queue.
#'
#' @param path the full path to the new file or directory. A single
#'     file is treatedas if it were a directory holding only that file
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @return  TRUE iff all files were handled.
#'
#' The algorithm is this:
#' \itemize{
#'
#'    \item any .DTA (Lotek) files are moved into a new temporary
#' directory whose name ends with _dta, which is then enqueued.
#'
#'    \item any folder with a file named "syslog" is given a new name
#' that ends with "_log", and is enqueued
#'
#'    \item any files with names ending in ".gz" or ".txt.gz", or
#' which have an 8.3 character filename that includes a tilde ("~")
#' character are moved into a new temporary directory whose name
#' ends with _sg, which is then enqueued. See the references
#' regarding 8.3 filenames
#'
#'    \item any remaining files of recognized type are enqueued
#' individually
#'
#' }
#'
#' @seealso \code{\link{server}}
#'
#' @references https://en.wikipedia.org/wiki/8.3_filename
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handlePath = function(path, isdir) {

    ## treat single file as folder with single file

    if (! isdir) {
        newdir = makeQueuePath("file")
        newpath = file.path(newdir, basename(path))
        file.rename(path, newpath)
        path = newpath
    }

    all = dir(path, recursive=TRUE, full.names=TRUE)

    ## look for .DTAs

    dta = grep("(?i)\\.DTA$", all, perl=TRUE)
    if (length(dta)) {
        newdir = makeQueuePath("dta")
        file.rename(all[dta], file.path(newdir, basename(all[dta])))
        enqueue(newdir)
        all = all[ - dta]
    }

    ## look for folders containing a file called 'syslog'

    syslog = grep("^syslog$", basename(all), perl=TRUE)
    if (length(syslog)) {
        for (d in sylog)
            enqueue(dirname(all[d]), "log")
        all = all[ - syslog ]
    }

    ## look for names of raw sensorgnome data files
    ## These long names sometimes get converted to 8.3 character filenames,
    ## which include a tilde

    sg = grep("(\\.txt(\\.gz)?$)|~", all, perl=TRUE)
    if (length(sg)) {
        newdir = makeQueuePath("sg")
        file.rename(all[sg], file.path(newdir, basename(all[sg])))
        enqueue(newdir)
        all = all[ - sg ]
    }

    ## treat all remaining files individually; they are presumably
    ## compressed archives

    queueKnownFiles(path)

    return(TRUE)
}
