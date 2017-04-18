#' get a view of tag detections with the same columns as the old-style
#' "global" tags file
#'
#' @param t view of full tag detection join, as returned by \code{\link{tagview}}
#'
#' @return a new dplyr::tbl with columns matching those in the original sensorgnome
#' "globaltags" files, and rows ordered by (ts, site, ant)
#'
#' The columns in that file are:
#'
#'   > names(x)
#'    [1] "ant"       "ts"        "fullID"    "freq"      "freqsd"    "sig"
#'    [7] "sigsd"     "noise"     "runID"     "posInRun"  "slop"      "burstSlop"
#'   [13] "antFreq"   "depID"     "tsOrig"    "bootnum"   "runLen"    "id"
#'   [19] "tagProj"   "nomFreq"   "lat"       "lon"       "alt"       "depYear"
#'   [25] "proj"      "site"      "recv"      "sp"        "label"     "gain"
#'   [31] "dbm"
#'   > x[1,]
#'         ant                  ts               fullID  freq freqsd   sig sigsd
#'   22510  3  1970-01-01 00:23:15 USask#161@166.38:6.1 4.487 0.0426 -65.4  33.5
#'         noise runID posInRun    slop burstSlop antFreq depID   tsOrig bootnum
#'   22510 -77.2    59        1 0.00055         0 166.376     1 1395.624      35
#'         runLen  id tagProj nomFreq   lat       lon  alt depYear  proj  site
#'   22510      6 161   USask  166.38 45.09 -64.36944 37.6    2016 USask ReedW
#'                    recv sp                     label gain    dbm
#'   22510 SG-3214BBBK8680    USask 161  :6.1 @ 166.38     0 -115.4
#'
#' @note: the following fixups must be made to data returned by this view
#' to match the original columns.  The fixups have to be made after calling
#' collect() and then as.data.frame() on the view returned by this function.
#'
#'     posInRun <- fixPosInRun(X) where X is the data.frame
#'
#'     proj <- as.factor(proj)
#'
#'     tagProj <- as.factor(tagProj)
#'
#'     site <- as.factor(site)
#'
#'     fullID <- as.factor(fullID)
#'
#'     depYear <- as.integer(substr(depYear, 1, 4))
#'
#'     id <- as.integer(id)
#'
#'     label <-as.factor(paste0("M." + label))
#'
#' @export
#'
#' @seealso \code{\link{exportGlobalTags}} and \code{\link{tagview}}
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

getGlobalTagsView = function(t) {
    if (! inherits(t, "tbl")) {
        stop("t must be a dplyr::tbl, such as returned by the tagview() function")
    }
    return (
        t %>% transmute(
                  ant = ant,
                  ts = ts,
                  fullID = fullID,
                  freq = freq,
                  freqsd = freqSD,
                  sig = sig,
                  sigsd = sigSD,
                  noise = noise,
                  runID = runID,
                  posInRun = 0,
                  slop = slop,
                  burstSlop = burstSlop,
                  antFreq = nomFreq,    ## FIXME: should be frequency antenna actually tuned to
                  bootnum = monoBN,
                  runLen = len,
                  id = mfgID,           ## grab as integer below
                  tagProj = label,      ## label of tags's project
                  nomFreq = nomFreq,
                  lat = `latitude:2`,   ## from recvDep
                  lon = `longitude:2`,  ## from recvDep
                  alt = elev,
                  depYear = dateBin,    ## grab as year below
                  proj = `label:1`,      ## label of receiver's project
                  site = name,          ## from recvDep
                  recv = serno,
                  sp = english,         ## fixme: english name, should be 4-letter code
                  label = tagID,        ## fixme: make this "M." + motus tag ID
                  gain = 0,
                  dbm = sig             ## fixme: subtract 50 for funcube, calcurve for Lotek
              )
        %>% arrange(ts, site, ant)
    )
}
