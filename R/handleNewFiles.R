#' handle a new batch of files
#'
#' Called by \code{\link{processServer}}.  Any files in subfolders
#' of the specified job's folder are processed.
#'
#' @param j the job
#'
#' @return  TRUE; As a side effect, subjobs for handling
#' various types of known files are queued, like so:
#'
#' \itemize{
#'
#'    \item any .DTA (Lotek) files are moved into a new temporary
#' directory and queued as a subjob of type "DTA"; name collisions
#' are avoided
#'
#'    \item any folder containing a file named "syslog(.[0-9](.gz)?)?"
#' is enqueued as a new subjob of type "logs"
#'
#'    \item any files that don't look like sensorgnome data files,
#' i.e. that don't have names ending in ".gz" or ".txt.gz", and which
#' aren't shortened names with a tilde ("~") character are moved into
#' a new directory and enqueued as a subjob of type "unknownFiles".
#'
#'    \item any remaining files are assumed to be SG data files, and
#' a subjob of type "SGfiles" is enqueued to process them.
#'
#' }
#'
#' @seealso \code{\link{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleNewFiles = function(j) {

    all = dir(list.dirs(j$path, recursive=FALSE), recursive=TRUE, full.names=TRUE)

    ## look for .DTAs

    dta = grep("(?i)\\.DTA$", all, perl=TRUE)
    if (length(dta)) {
        sj = newSubJob(j, "DTA", .makeFolder=TRUE)
        moveFilesUniquely(all[dta], sj$path)
        queueJob(sj)
        all = all[ - dta]
    }

    ## look for folders containing a file called 'syslog'

    syslog = grep("^syslog(\\.[0-9](\\.gz)?)?$", basename(all), perl=TRUE)
    if (length(syslog)) {
        for (d in unique(dirname(all[syslog]))) {
            sj = newSubJob(j, "logs", .makeFolder=TRUE)
            moveDirContents(d, j$path)
            queueJob(sj)
        }
        all = all[ - syslog ]
    }

    ## look for files that don't look like sensorgnome data files
    ## SG long filenames sometimes get converted to 8.3 character filenames,
    ## which include a tilde.

    unknown = grep("(\\.txt(\\.gz)?$)|~", all, perl=TRUE, invert=TRUE)
    if (length(unknown)) {
        sj = newSubJob(j, "unknownFiles", .makeFolder=TRUE)
        moveFilesUniquely(all[unknown], sj$path)
        queueJob(sj)
        all = all[ - unknown ]
    }

    ## treat all remaining files as sensorgnome data files
    if (length(all))
        queueJob(newSubJob(j, "SGfiles"))

    return(TRUE)
}
