#' Save a folder of linux system log files from a sensorgnome.
#'
#' Called by \code{\link{processServer}} for a folder containing
#' a file called syslog
#'
#' @param j the job
#'
#' @return TRUE iff all files in the folder could be archived; i.e. iff a valid
#'     sensorgnome serial number was found in at least one of the log
#'     files
#' @note
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleLogs = function(j) {

    ## use zgrep to look for receiver serial number strings in
    ## possibly gz-compressed logfiles; note that grep returns 1 to indicate
    ## "match found", rather than an error.  So we specify minErrorCode=2

    path = jobPath(j)
    sernoRegex = paste0('(?i)(?<serno>', MOTUS_SG_SERNO_REGEX, ')')
    res = safeSys('zgrep -P -h --binary-files=text', paste0('"', sernoRegex, '"'), paste0(path, '/*'), '2>/dev/null | head -1l', shell=TRUE, quote=FALSE, minErrorCode=2)

    if (length(res) == 0)
        return (FALSE)   ## no serial number found

    ## split out the serial number
    serno = regexPieces(sernoRegex, res)[[1]]["serno"][1]

    ## archive the folder
    newdir = file.path(MOTUS_PATH$RECVLOG, serno, format(file.mtime(path), "%Y-%m-%dT%H-%M-%S"))
    dir.create(newdir, recursive=TRUE, showWarnings=FALSE)

    rv = all(moveDirContents(path, newdir))

    jobLog(j, paste0("Saved SG log files to ", newdir))

    return(rv)
}
