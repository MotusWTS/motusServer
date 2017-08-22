#' fully re-run all raw data files from a receiver
#'
#' Called by \code{\link{processServer}}
#'
#' @details re-creates the tables in the receiver DB from scratch,
#' using the files stored in \code{MOTUS_PATH$FILE_REPO/serno},
#' and then runs the tag finder on all data.
#'
#' @param j the job with these items:
#'
#' \itemize{
#'
#' \item serno character scalar; the receiver serial number
#'
#' }
#'
#' @return TRUE
#'
#' @seealso \link{\code{processServer}}, \link{\code{handleRerunReceiver}} which reruns
#' the tag finder on some or all data, but without rebuilding file contents tables
#' from the file repository.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleFullRecvRerun = function(j) {
    serno = j$serno

    lockSymbol(serno)

    ## make sure we unlock the receiver DB when this script ends,
    ## even on error.

    on.exit(lockSymbol(serno, lock=FALSE))

    ## delete table contents, including those holding files
    cleanup(getRecvSrc(serno), dropTables=TRUE, dropFiles=TRUE)

    ## create and enqueue the subjob which will handle this recv's
    ## repo files as if they were entirely new

    sj = newSubJob(j, if (grepl("^SG-", serno, perl=TRUE)) "SGfiles" else "LtFiles", .makeFolder = FALSE)
    sj$filePath = file.path(MOTUS_PATH$FILE_REPO, serno)

    return(TRUE)
}
