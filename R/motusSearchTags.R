#' return a list of all motus tags
#'
#' @param projectID: integer scalar; motus internal project ID
#'
#' @param tsStart: numeric scalar; start of active period
#'
#' @param tsEnd: numeric scalar; end of active period
#'
#' @param searchMode: character scalar; type of search
#'     desired. "overlaps" looks for tags active during at least a
#'     portion of the time span \code{c(tsStart, tsEnd)}, while
#'     "startsBetween" looks for tags with deployment start times in
#'     the same range.
#'
#' @param defaultLifeSpan: integer scalar; default lifespan of tags,
#'     in days; used when motus does not know the lifespan for a tag.
#'
#' @param lifeSpanBuffer: numeric scalar; amount by which nominal
#'     lifespan is multiplied to get maximum possible lifespan.
#'
#' @param regStart: numeric scalar; if not NULL, search for tags
#'     registered no earlier than this date, and ignore deployment
#'     dates.
#'
#' @param regEnd: numeric scalar; if not NULL, search for tags
#'     registered no later than this date, and ignore deployment
#'     dates.
#'
#' @param mfgID: character scalar; typically a small integer; return
#'     only records for tags with this manufacturer ID (usually
#'     printed on the tag)
#'
#' @param ...: additional parameters to motusQuery()
#'
#' @return the data.frame of motus tags and their meta data satisfying
#'     the search criteria, or NULL if there are none.  The data.frame
#'     has these columns:
#'
#' \itemize{
#'    \item tagID
#'    \item projectID
#'    \item mfgID
#'    \item dateBin
#'    \item type
#'    \item codeSet
#'    \item manufacturer
#'    \item model
#'    \item lifeSpan
#'    \item nomFreq
#'    \item offsetFreq
#'    \item period
#'    \item periodSD
#'    \item pulseLen
#'    \item param1
#'    \item param2
#'    \item param3
#'    \item param4
#'    \item param5
#'    \item param6
#'    \item param7
#'    \item param8
#'    \item tsSG
#'    \item approved
#'    \item deployID
#'    \item status
#'    \item tsStart
#'    \item tsEnd
#'    \item deferSec
#'    \item speciesID
#'    \item markerNumber
#'    \item markerType
#'    \item latitude
#'    \item longitude
#'    \item elevation
#'    \item comments
#' }
#'
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusSearchTags = function(projectID = NULL, tsStart = NULL, tsEnd = NULL, searchMode=c("startsBetween", "overlaps"), defaultLifespan=90, lifespanBuffer=1.5, regStart = NULL, regEnd = NULL, mfgID = NULL, ...) {
    searchMode = match.arg(searchMode)

    colsNeeded = c("tagID","projectID","mfgID","dateBin","type","codeSet","manufacturer","model","lifeSpan","nomFreq","offsetFreq","period","periodSD","pulseLen","param1","param2","param3","param4","param5","param6","param7","param8","tsSG","approved","deployID","status","tsStart","tsEnd","deferSec","speciesID","markerNumber","markerType","latitude","longitude","elevation","comments")

    rv = motusQuery(MOTUS_API_SEARCH_TAGS, requestType="get",
               list(
                   projectID = projectID,
                   tsStart   = tsStart,
                   tsEnd     = tsEnd,
                   searchMode = searchMode,
                   defaultLifespan = defaultLifespan,
                   lifespanBuffer = lifespanBuffer,
                   regStart  = regStart,
                   regEnd    = regEnd,
                   mfgID     = mfgID
               ), ...)

    if (! isTRUE(nrow(rv) > 0))
        return(NULL)

    ## remove "TEST" records, which aren't real tags
    rv = subset(rv, ! grepl("^TEST", mfgID, perl=TRUE))

    ## fill in any missing columns, then return in stated order
    for (col in colsNeeded) {
        if (is.null(rv[[col]]))
            rv[[col]] = NA
    }
    return(rv[, colsNeeded])
}
