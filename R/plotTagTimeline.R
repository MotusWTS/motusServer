0#' plot a timeline of all deployed tags
#'
#' This generates an html file with preformatted text which shows
#' a tag timeline when viewed in a fixed-width font.
#'
#' @param sort character vector of field names by which to sort.  Default:
#' NULL, which means sort by \code{projCode, sort, nomFreq, mfgID} (i.e.
#' by manufacturer's tag ID within nominal frequency within taxonomic
#' species order, within project code.
#'
#' @param filename filename to save plot; Default: "/sgm/pub/motus_tag_timeline.html"
#'
#' @return a data_frame with these columns:
#' \itemize{
#' \item motusID
#' \item projectID
#' \item projCode
#' \item fullID
#' \item mfgID
#' \item nomFreq
#' \item period
#' \item speciesID
#' \item speciesName
#' ...
#' }
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

plotTagTimeline = function(sort = c("projCode", "dateBin", "sort", "nomFreq", "iMfgID"), filename="/sgm/pub/motus_tag_timeline.html") {
    f = file(filename, "w")
    s = src_sqlite(getMotusMetaDB())
    mot = tbl(s, "tags")
    proj = tbl(s, "projs") %>% mutate(projCode=label)
    sp = tbl(s, "species")
    hist = mot %>% collect
    hist = hist %>%
        left_join (sp, by=c(speciesID="id"), copy=TRUE) %>%
        left_join (proj, by=c(projectID="id"), copy=TRUE) %>%
        mutate_ (fullID = ~sprintf("%s#%s@%g:%.1f", projCode, mfgID, nomFreq, period),
                 iMfgID = ~as.integer(mfgID)) %>%
        collect %>% as.data.frame
    hist$english[is.na(hist$english)] = " ? "
    hist = hist[do.call(order, hist[,sort]), ]
    hist = subset(hist, ! projCode %in% c("Lorng", "Loring"))
    class(hist$tsStart) = class(hist$tsEnd) = c("POSIXt", "POSIXct")
    idw = max(nchar(hist$fullID))
    nmw = max(nchar(hist$english))
    hdr = stri_dup(" ", idw + nmw + 1 + 6 + 6)
    years = year(min(hist$tsStart)) : year(max(hist$tsEnd))
    numYears = length(years)
    moStart = ymd(outer(1:12, years, function(x,y) paste(y, x, 1, sep="-")))
    moEnd = c(moStart[-1] - 24*3600, tail(moStart, 1) + 31 * 24 * 3600)
    ystr = paste0(sprintf(paste0("%", nmw, "s|   Motus   |%", idw, "s|%s"), "Species Name", "Full Tag ID", "Span"), "|", paste(sprintf("    %4d    ", years), collapse="|"))
    mstr = paste0(sprintf(paste0("%", nmw, "s|Pr.ID|TagID|%", idw, "s|Code"), "", ""), "|", paste(rep("JFMAMJJASOND", numYears), collapse="|"))
    sep = paste0(stri_dup("-", nchar(hdr)), "|", paste(rep("------------", numYears), collapse="+"))
    empty = stri_dup(" .", 6 * numYears)
    hist$col1 = 12 * (year(hist$tsStart) - years[1]) + month(hist$tsStart)
    hist$col2 = 12 * (year(hist$tsEnd) - years[1]) + month(hist$tsEnd)
    hist$line = empty
    stri_sub(hist$line, from=hist$col1, to=hist$col2) = stri_dup("X", hist$col2-hist$col1 + 1)
    hist$line=stri_replace_all(hist$line, "$1|", regex="([. X]{12})(?=[. X])")
    hist$line = sprintf(paste0("%", nmw, "s|%5d|%5d|%", idw, "s|%1d-%1d |%s"), hist$english, hist$projectID, hist$tagID, hist$fullID, hist$tsStartCode, hist$tsEndCode, hist$line)
    writeLines('
<html>
<head>
<meta http-equiv="cache-control" content="max-age=0" />
<meta http-equiv="cache-control" content="no-cache" />
<meta http-equiv="expires" content="0" />
<meta http-equiv="expires" content="Tue, 01 Jan 1980 1:00:00 GMT" />
<meta http-equiv="pragma" content="no-cache" />
</head>
<body>
<h3>Motus Tag Deployment Windows - Generated', f)
    writeLines(format(Sys.time()), f)
    writeLines(' </h3>
Estimated tag deployment windows are shown, rounded outward to the nearest month boundary<br>
(i.e. an <em>X</em> is shown if the tag was active during any portion of the month).<br>
<br>
SpanCode indicates how lifespan was computed.  A span code of X-Y indicates<br>
the start date was computed using method X, and the end date was computed using method Y,<br>
where X and Y are indicated in the list below.<br><br>
Start dates are selected using these items from the <a href="http://motus.org">motus</a> database,<br>
in order of preference (i.e. the first available  item is used):<br>
<ul>
 
 <li> tsStart - the starting date for a tag deployment record; spanCode X=1
 <li> dateBin - the start of the quarter year in which the tag was expected to be deployed; spanCode X=2
<li> ts - the date the tag was registered; spanCode X=3

</ul>
<br>
Tag deactivation events are generated using these items, again in order of preference:<br>
<ul>

 <li> <em>tsEnd</em> - the ending date for a tag deployment; e.g. if a tag was found, or manually deactivated; spanCode Y=1

<li> <em>tsStart</em> for a different deployment of the same tag; spanCode Y=2

<li> <em>tsStart + predictTagLifespan(model, BI) * marginOfError</em> , if the tag model is known; spanCode Y=3

<li> <em>tsStart + >predictTagLifespan(guessTagModel(speciesID), BI) * marginOfError</em>
 , if the species is known; spanCode Y=4

<li> 90 days if no other information is available; spanCode Y=5

</ul>

<em>BI</em> is the tag burst interval, in seconds, and <em>marginOfError</em> has been chosen to be 50%.<br>
<em>predictTagLifespan</em> is an R function that models tag life as a function of tag model and burst interval;<br>
it is based on a simple model of power consumption, and agrees well with the specs
 published by Lotek.  Details of the model are <a href="https://github.com/jbrzusto/motus-R-package/blob/master/modelLotekTagLifeSpan.pdf">here.</a></br>

<em>guessTagModel</em> associates a default tag model with each species,<br>
where we have reason to believe that model is the one most commonly used for it.<br>
<br>
<pre>', f)
    linesPerChunk = 40
    i = 1
    numChunk = ceiling(nrow(hist) / linesPerChunk)
    for (i in 1:numChunk) {
        writeLines(c(ystr, mstr), f)
        li = seq(from = 1 + (i - 1) * linesPerChunk, to = min(nrow(hist), i * linesPerChunk ))
        writeLines(hist$line[li], f)
        i = i + linesPerChunk
    }
    writeLines("</pre></body</html>", f)
    close(f)
    return(invisible(hist))
}

