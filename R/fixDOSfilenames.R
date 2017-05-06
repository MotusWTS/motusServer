#' Correct DOS-style 8.3 filenames into (almost) their original full filenames.
#'
#' Any files needing renaming are renamed on disk. The corrected
#' filename will have the receiver serial number, the first timestamp
#' from the file, and a boot number of 0.  This flags the requirement
#' to correct the boot number after other files have been merged into
#' their receiver databases.
#'
#' @note this function should be made trivial in the future by writing
#'     the bootnum and serial number at the start of each file.
#'
#' @details Some users move SG data files along a route that fails to
#'     preserve their long filenames, forcing them into a DOS-style
#'     8.3 filename.  Typically, this only happens to a few files per
#'     batch, for some reason.  Perhaps they are storing raw files in
#'     the top level folder of a VFAT filesystem, which limits the
#'     total length of filenames in a folder.
#'
#' In any case, these can be recognized by a tilde \code{~} in the
#' filename, and the first two letters of the shortened name will
#' match (case insensitively) the first two letters of the original
#' full name.
#'
#' @param f vector of full paths to files
#'
#' @param info data frame of split filename components, which are the
#'     named capture groups in \link{\code{sgFilenameRegex}}
#'
#' @return info, with corrections to those rows representing DOS-style
#'     filenames whose receiver can be deduced.
#'
#' @note Corrections require inferring the serial number and boot
#'     count for any 8.3 filename, and then using the timestamp from
#'     the first record in the file as the file timestamp.
#'
#' \itemize{
#' \item for each 8.3 filename, we use as context the file's folder
#'
#' \item if the first two characters of the
#' shortened name match (case insensitively) the
#' first two characters of any file with unshortened name in the context.
#' If so, and if the matching full-named files all have the same serial
#' number, correct appropriately.
#'
#' \item otherwise, we can't tell what receiver the file belongs to,
#' and we leave its receiver column as NA. FIXME: get first and last
#' timestamps in shortened files and compare to timestamps parsed from
#' full names.
#'
#' }
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

fixDOSfilenames = function(f, info) {
    ## which filenames are short, if any
    base = basename(f)
    dos = grep(MOTUS_DOS_FILENAME_REGEX, base, perl=TRUE)

    if (! length(dos))
        return(info)

    ## upper case first two chars of all names
    twoChar = toupper(substr(base, 1, 2))

    for (i in dos) {
        ## we try to generate as many of these fields (from sgFilenameRegex) as possible:
        ## prefix, serno, bootnum, ts, tscode, port, extension, comp

        ## get the context; those files in the same folder
        context = which(dirname(f) == dirname(f[i]))

        ## which files match by first two characters and have valid serial numbers?
        matches = context[twoChar[context] == twoChar[i] & ! is.na(info$serno[context])]
        sernos = unique(info$serno[matches])

        if (length(sernos) == 1) {
            ## there's only a single match, so it must be that receiver
            info$prefix[i] = info$prefix[matches[1]]
            info$serno[i] = sernos

            ## if the boot number is unique among matches, use it;
            ## otherwise, bootnum will be determined later, using
            ## timestamps of other files for this receiver, so flag as 0.

            if (length(unique(info$bootnum[matches])) == 1) {
                info$bootnum[i] = info$bootnum[matches[1]]
            } else {
                info$bootnum[i] = 0
            }

            ## grab the first timestamp in the file, and use that as the
            ## file timestamp; 2nd column is timestamps; we grab 100 lines
            ## in case there are NA timestamps

            ts = read.csv(gzfile(f[i], "r"), header=FALSE, as.is=TRUE, nrow=100, comment.char="#")[, 2]
            ts = ts[! is.na(ts)][1]  ## drop NA timestamps; might not have any left
            if (! is.na(ts)) {
                ## there's at least one non-NA timestamp;
                ## correct timestamp if from CLOCK_MONOTONIC
                if (ts < 946684800) ## this is the beaglebone epoch
                    ts = ts + 946684800
                ## use this as the file timestamp
                info$tsString[i] = format(structure(ts, class=c("POSIXt", "POSIXct")), MOTUS_SG_TIMESTAMP_FORMAT)

                ## assign tsCode as "P" if timestamp is pre-GPS; otherwise, "Z"
                info$tsCode[i] = if(ts < 1262304000) "P" else "Z"
            }
            ## these two are universal in SG output files, except for .wav files
            info$port[i] = "all"
            info$extension[i] = ".txt"
            info$comp = if (toupper(substring(base[i], nchar(base[i]) - 1)) == "GZ") ".gz" else ""
        }
    }
    return(info)
}
