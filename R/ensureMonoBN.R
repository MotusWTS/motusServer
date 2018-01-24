#' Ensure we have monotonic boot numbers for a receiver database.
#'
#' Sensorgnomes are supposed to know how many times they've been booted,
#' and record this \emph{bootnum} in the name of each file they write.
#' One use of this information is to position batches of files in real
#' time if they were recorded during a boot session when the SG failed
#' to set its clock to GPS time.  These files will then appear to have
#' been written in the year 2000.  If the boot session before or after
#' the problematic one \emph{is} correctly dated, that lets us
#' bracket the time interval in which the undated boot session must belong.
#'
#' Unfortunately, this scheme has failed in a few situations:
#' \itemize{
#'
#'   \item on beaglebone whites (BBW) where the SD card is changed
#'   between boot sessions.  The boot count is stored on the SD card
#'   (there is no internal storage on the BBW), and there's no
#'   mechanism in place to set the boot count correctly when a new
#'   card is used.
#'
#'   \item on beaglebone blacks using a software image from some time
#'   in 2014(?) when the boot count was not updated correctly if it
#'   was at 2; in that case it is stuck at 2.
#'
#'   \item on beaglebone blacks re-imaged using a software image that
#'   did not preserve the boot count on the target BBBK.  (I don't
#'   remember exactly which version(s) were affected).
#'
#'   \item more generally, see https://github.com/jbrzusto/sensorgnome/issues/53
#' }
#'
#' This function can test for and correct non-monotonic boot counts.
#'
#' @param src dplyr:src_sqlite open to an existing receiver database
#'
#' @param testOnly logical scalar; default FALSE.
#'
#' @return if \code{testOnly==TRUE}:
#' \itemize{
#' \item return TRUE if a non-monotonicity
#' in bootnum is detected; ie. if there exist two files F1 and F2
#' such that \code{F1$ts > MOTUS_SG_EPOCH && F2$ts > MOTUS_SG_EPOCH && F1$ts > F2$ts && F1$bootnum < F2$bootnum}
#' \item return FALSE otherwise
#' }
#' if \code{testOnly==FALSE}: return TRUE iff monoBN values were changed
#' for any file.
#'
#' @note If \code{testOnly==FALSE}, then change might be made to the monoBN field
#' in file records.  Any such changes are recorded in the bootnumChanges table.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureMonoBN = function(src, testOnly = FALSE) {
    sql = safeSQL(src)
    sql("drop table if exists _bn_times")
    sql("create temporary table _bn_times as select bootnum, min(ts) as min, max(ts) as max from files where ts > 1000000000 group by bootnum")
    inv = sql("select t1.*, t2.* from _bn_times as t1 join _bn_times as t2 on t1.bootnum < t2.bootnum where not (t1.max <= t2.min or t2.max <= t1.min)")
    haveInv = isTRUE(nrow(inv) > 0)
    if (testOnly)
        return (haveInv) ## inform caller
    if (!haveInv)
        return(FALSE) ## nothing to do

    ## calculate bootnum->monoBN map:
    ## The algorithm, ignoring files with PRE-SG timestamps (< MOTUS_SG_EPOCH, meaning not yet set by GPS) is:
    ## monoBN <- 1
    ## repeat {
    ##    - peel off the earliest, maximal, contiguous set of files having the same bootnum,
    ##    and give those the current monoBN.
    ##    - increment monoBN
    ## }
    ## A subset F of files from set G is "contiguous" iff all F have the same bootnum, and any
    ## file in G but not in F has timestamp outside the range of F's timestamps).
    ## i.e.: length(unique(F$bootnum)) == 1 && all(subset(G, bootnum != F$bootnum[1])$ts > max(F$ts)
    ##
    ## We get the maximal F by choosing those files having (real) timestamp smaller than any timestamp
    ## for any other bootnum.

    G = sql("select * from files where ts > %f", MOTUS_SG_EPOCH)
    origMonoBN = G$monoBN
    G$monoBN = 0
    monoBN = 1L
    newG = NULL
    while(nrow(G) > 0) {
        ## get the bootnum corresponding to the earliest (real) timestamp
        bn = G$bootnum[which.min(G$ts)]
        tsNext = min(subset(G, bootnum != bn)$ts)
        ## even if the above subset was empty, this works,
        ## because tsNext will be Inf.
        peel = with(G, bootnum == bn & ts < tsNext)
        g = subset(G, peel)
        G = subset(G, ! peel)
        g$monoBN = monoBN
        newG = rbind(newG, g)
        monoBN = monoBN + 1L
    }

    ## Now try to assign a monoBN to those files without a valid timestamp.
    ## First, try to get a sane timestamp for any file not having one, by scanning
    ## the file for pulse or parameter-setting records with valid timestamps
    bad = sql("select * from files where ts <= %f", MOTUS_SG_EPOCH)
    if (isTRUE(nrow(bad) > 0)) {
        origMonoBN = c(origMonoBN, bad$monoBN)
        bad$monoBN = 0L
        class(bad$ts) = c("POSIXt", "POSIXct")
        serno = sql("select val from meta where key='recvSerno'")[[1]]
        badpath = file.path(MOTUS_PATH$FILE_REPO, serno, format(bad$ts, "%Y-%m-%d"), bad$name)
        for (i in 1:nrow(bad)) {
            recs = NULL
            if (file.exists(badpath[i])) {
                ## try text version
                recs = readLines(badpath[i])
            } else {
                ## try compressed (.gz) version
                badpath[i] = paste0(badpath[i], ".gz")
                if (file.exists(badpath[i])) {
                    gzcon = gzfile(badpath[i], "rb")
                    recs = readLines(gzcon)
                    close(gzcon)
                }
            }
            if (length(recs) > 0) {
                ## examine p, S, and C records, as these issue a system timestamp
                ## (skip G records as these might be flaky due to a stuck GPS)
                recs = read.csv(textConnection(grep("^[pSC]", recs, value=TRUE)), header=FALSE)
                if (isTRUE(nrow(recs) > 0)) {
                    tsfix = max(recs[,2])
                    if (tsfix > MOTUS_SG_EPOCH) {
                        ## monoBN is smallest bootnum for which there are files with
                        ## larger real timestamps
                        bad$monoBN[i] = min(newG$monoBN[newG$ts > tsfix])
                    }
                }
            }
        }
    }
    newG = rbind(newG, bad)
    sql("delete from files")
    dbWriteTable(sql$con, "files", newG, row.names=FALSE, append=TRUE)

    return(! identical(origMonoBN, newG$monoBN))
}
