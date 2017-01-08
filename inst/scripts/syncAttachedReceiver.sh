#' Grab and process new files from an attached SG.
#'
#' Uses rsync to copy/update files from the receiver into the
#' \code{MOTUS_PATH$FILE_REPO} folder, then queues a job to process
#' these files.  This function can be called from a script that
#' runs as a cron job, for example.
#'
#' @param serno receiver serial number
#'     the full path to a directory, which will be searched
#'     recursively for raw sensorgnome data files.
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{MOTUS_PATH$RECV}
#'
#' @return a list with two items:
#' \itemize{
#' \item info- a data_frame reporting the details of each file, with these columns:
#' \itemize{
#' \item name - full path to filename
#' \item use - TRUE iff data from this file will be incorporated in this run (i.e. the file is new, or has
#' more content than its previous version)
#' \item new  - TRUE iff a file of this name was not yet in database
#' \item done  - TRUE iff this is a compressed file and we have its full contents
#' \item corrupt      - TRUE the file was compressed but corrupted
#' \item small - TRUE iff the file contents are shorter than existing contents for that file in the receiver DB
#' \item partial - TRUE iff this is a partial compressed file for which an uncompressed version is in the same batch
#' \item serno - serial number of the receiver, parsed from this filename
#' \item monoBN - monotonic boot session, parsed from filename
#' \item ts - starting timestamp, parsed from filename
#' }
#' \item resumable - a logical vector indicating the tag finder can be run with --resume for each
#' subset of files from a distinct (serno, monoBN) pair.  The vector has names consisting of
#' \code{paste(serno, monoBN)}.
#' }
#'
#' Returns NULL if no valid sensorgnome data files were found.
#'
#' @export
#'
#' @seealso \code{sgRunNewFiles}, which calls this function and then calls \code{sgFindTags}
#' as appropriate.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
