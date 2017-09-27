#' repackage recovered data into hourly files with appropriate names
#'
#' When raw SG records are recovered from a failed SD card, they need
#' to be grouped into files so that the usual processing code can
#' handle them.  This function does so, then optionally submits the
#' repackaged archive as a file upload to the motus server so that
#' it will be incorporated into the appropriate receiver's DB and
#' then processed.
#'
#' @param filename path to file containing recovered records.
#'
#' @param serno character scalar receiver serial number; this is not
#'     available in records themselves, unfortunately.  Care must be
#'     taken to ensure the correct serial number is given, otherwise
#'     data will appear to come from the wrong receiver.  The GPS
#'     records are used to provide a sanity check on this, if a
#'     deployment for the receiver is known.
#'     example:  "SG-1234BBBK5678"
#'
#' @param bootnum starting boot number of the data, if known.
#'     Default: 1000.  This function tries to detect reboots by
#'     looking for large backward time jumps, but this doesn't always
#'     work, as SGs with cape GPS usually set their system time from
#'     battery-backed realtime clock clock before any file records are
#'     written.
#'
#' @param path character scalar: path in which to create the .zip archive
#' of hourly files.  Default: \code{getwd()}
#'
#' @param submit logical scalar: if TRUE, "upload" the file so it is
#' processed by the motus data-processing server.  Default: FALSE
#'
#' @return character scalar; path to the .zip archive of hourly files created
#' by this function.
#'
#' @details data records can sometimes be extracted from a failed SD card by
#' directly reading blocks from the device and searching for strings of the appropriate
#' form.  With a VFAT file system and the usual SG filing method of "write .txt and .txt.gz
#' files in tandem; delete .txt when .txt.gz is complete", the records written to and deleted
#' as uncompressed .txt files are added to the back of the filesystem's free block list, so are
#' rarely overwritten.  When an SD card is represented by /dev/mmcblk1, the records can be
#' extracted by a root shell (on whichever device holds the SD card) with this command:
#'
#'    strings /dev/mmcblk1 | grep -P '^(G|S|C|T|p[0-9]),[0-9]+([.0-9]+)?,' > recovered_records.txt
#'
#' or, if the card is installed in a remote SG which has connected to
#' the motus/SG server with reverse tunnel port 43210 (for example),
#' this command on the server:
#'
#'    sshpass -p root ssh -T -f -p 43210 root@localhost "strings /dev/mmcblk1 | grep -P '^(G|S|C|T|p[0-9]),[0-9]+([.0-9]+)?,'" > recovered_records.txt &
#'
#' will extract the records on the SG and send them via SSH to the file recovered_records.txt on the server.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

repackageRecoveredSGdata = function(filename, serno, bootnum=1000, path=getwd(), submit=FALSE) {

    chunkSize = 10000
    outf = NULL
    lastdate = ""
    i = chunkSize + 1
    lastts = 0

    ## create a temporary subfolder for the YYYY-MM-DD hierarchy
    filedir = tempfile(tmpdir = path)
    dir.create(filedir)

    ## files will start on-the-hour
    outfTemplate = paste0('recovered-', substring(serno, 4), '-%06d-%s-00-00P-all.txt.gz')

    f = file(filename, "r")

    while (TRUE) {
        ## process one line at a time, but do reading and splitting in chunks
        if (i > chunkSize) {
            x = readLines(f, n=chunkSize)
            if (length(x) == 0)
                break
            parts = strsplit(x, ",", fixed=TRUE)
            ## grab timestamps
            ts = structure(as.numeric(sapply(parts, function(x) x[2])), class=c("POSIXt", "POSIXct"))
            dates = strftime(ts, "%Y-%m-%dT%H")
            i = 1
        }
        ## whole lines are stored in x
        ## their timestamps are stored in ts
        ## their formatted dates are stored in dates
        ## in each case, the current line is indexed by i

        if (length(parts[[i]]) < 3 || is.na(ts[i])) {
            i = i + 1
            next
        }

        ## for non-GPS records
        if (parts[[i]][1] != "G") {
            ## check for a time reversal (jump back by at least 1 hour)
            if (ts[i] < lastts - 3600) {
                bootnum = bootnum + 1
                if (!is.null(outf))
                    close(outf)
                outf = NULL
            } else if (dates[i] != lastdate) {
                ## check for a new date
                if (!is.null(outf))
                    close(outf)
                outf = NULL
                lastdate = dates[i]
            }
            lastts = ts[i]
        }
        ## ensure we have an output file
        if (is.null(outf)) {
            datedir = file.path(filedir, substring(lastdate, 1, 10))
            if (! file.exists(datedir))
                dir.create(datedir)
            outf = gzfile(file.path(datedir, sprintf(outfTemplate, bootnum, lastdate)), "a")
            cat ("Doing ", sprintf(outfTemplate, bootnum, lastdate), "\n")
        }
        cat(x[i], "\n", file=outf)
        i = i + 1
    }
    close(f)
    close(outf)
    safeSys("cd ", filedir, ";", "zip", "-r",  sprintf("../%s_recovered_files.zip", serno), ".", quote=FALSE)
}
