#' Save a folder of linux system log files from a sensorgnome.
#'
#' Called by \code{\link{server}} for a file or folder added
#' to the queue.
#'
#' @param path the full path to the file or directory.  It is only
#'     treated as a log file folder if it is a directory whose name
#'     begins with "log_"
#'
#' @param isdir boolean; TRUE iff the path is a directory
#'
#' @return TRUE iff the folder could be archived; i.e. iff a valid
#'     sensorgnome serial number was found in at least one of the log
#'     files
#' @note
#'
#' @seealso \link{\code{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleLogs = function(path, isdir) {
    if (! isdir || ! grepl("^log_", path, perl=TRUE))
        return (FALSE)

    ## use zgrep to look for receiver serial number strings in
    ## possibly gz-compressed logfiles

    res = system(sprintf('zgrep -P -h "%s" %s/* | head -1l', MOTUS_SG_SERNO_REGEX, path), intern=TRUE)

    if (length(res) == 0)
        return (FALSE)   ## no serial number found

    ## split out the serial number
    x = regexPieces(MOTUS_SG_SERNO_REGEX, res)

    ## archive the folder
    archivePath(path, file.path(MOTUS_PATH$RECVLOG, x[[1]]$serno[1]))

    return(TRUE)
}
