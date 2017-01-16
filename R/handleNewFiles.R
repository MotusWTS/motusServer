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

    ## list of original subjobs and folders
    ## (does not include subfolders created by subjobs in this function)
    ## We will be moving these into the subjob of type "newFiles" created
    ## at the end of this function.

    tj = topJob(j)
    originalSubjobs = children(tj)
    originalDirs = list.dirs(jobPath(j), recursive=FALSE)
    all = dir(originalDirs, recursive=TRUE, full.names=TRUE, all.files=TRUE)

    ## delete junk files
    junk = grep(MOTUS_JUNKFILE_REGEX, all, perl=TRUE)
    if (length(junk)) {
        toTrash(all[junk])
        eg = all[junk[1]]
        all = all[ - junk]
        jobLog(j, paste0("Deleted ", length(junk), " junk files with names like\n   ", eg))
    }

    ## look for .DTAs

    dta = grep("(?i)\\.DTA$", all, perl=TRUE)
    if (length(dta)) {
        sj = newSubJob(tj, "DTA", .makeFolder=TRUE)
        moveFilesUniquely(all[dta], jobPath(sj))
        all = all[ - dta]
    }

    ## look for folders containing a file called 'syslog'

    syslog = grep("^syslog(\\.[0-9](\\.gz)?)?$", basename(all), perl=TRUE)
    if (length(syslog)) {
        for (d in unique(dirname(all[syslog]))) {
            sj = newSubJob(tj, "logs", .makeFolder=TRUE)
            moveDirContents(d, jobPath(sj)) ## files will be moved before this process can run the newly queued job
        }
        all = all[ - syslog ]
    }

    ## look for files that don't look like sensorgnome data files
    ## SG long filenames sometimes get converted to 8.3 character filenames,
    ## which include a tilde.

    unknown = grep("(\\.txt(\\.gz)?$)|~", all, perl=TRUE, invert=TRUE)
    if (length(unknown)) {
        sj = newSubJob(tj, "unknownFiles", .makeFolder=TRUE)
        moveFiles(all[unknown], jobPath(sj))
        all = all[ - unknown ]
    }

    ## treat all remaining files as sensorgnome data files.
    ## We create a new subjob for these, and reparent any
    ## jobs that existed before this function was called
    ## and which have folders.  This is to accomplish
    ## a light-weight move of the putative SG files into
    ## their own filesystem tree, disjoint from the other
    ## trees for this top job.

    if (length(all)) {
        sj = newSubJob(tj, "SGfiles", .makeFolder = TRUE)
        for (jj in originalSubjobs) {
            job = Jobs[[jj]]  ## 'in' discards class attribute...
            if (jobHasFolder(job))
                reparentJob(job, sj)
        }
        ## move any remaining original folders to the job path; this will
        ## fail silently on those original folders which are job folders,
        ## because reparentJob() has already moved those.
        ## This step is mainly for scripts such as runNewFiles.R which leave
        ## a non-job subfolder in the "newFiles" job folder.
        moveFiles(originalDirs, jobPath(sj))
    }

    return(TRUE)
}
