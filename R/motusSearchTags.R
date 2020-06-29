#' return a list of all motus tags
#'
#' @param projectID: integer scalar; motus internal project ID
#'
#' @param tsStart: numeric scalar; unix timestamp; start of active period
#'
#' @param tsEnd: numeric scalar; unix timestamp; end of active period
#'
#' @param searchMode: character scalar; type of search
#'     desired. "overlap" looks for tags active during at least a
#'     portion of the time span \code{c(tsStart, tsEnd)}, while
#'     "startsBetween" looks for tags with deployment start times in
#'     the same range.
#'
#' @param mfgID: character scalar; typically a small integer; return
#'     only records for tags with this manufacturer ID (usually
#'     printed on the tag)
#'
#' @param status: integer; if non-NULL, returns only tags with the
#'     specified status.  1L = tag finished; 2L = tag active; 0L = tag
#'     not yet deployed
#'
#' @param tsLastModified: numeric scalar; unix timestamp; metadata
#'     modification threshold; if not NULL, only records modified
#'     since \code{tsLastModified} are returned.  Allows us to update
#'     the tagDeps records in the metadata cache.
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
#' @note As of 2018-08-24, filtering by `tsStart` and `tsEnd` fails to return any tags
#' whose `tsEnd` is NULL; see https://github.com/MotusDev/MotusAPI/issues/8
#'
#' @note support for \code{tsLastModified} is pending, so specifying it currently returns \code{data.frame()}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusSearchTags = function(projectID = NULL, tsStart = NULL, tsEnd = NULL, searchMode="startsBetween", mfgID = NULL, status = NULL, tsLastModified = NULL, ...) {
    searchMode = match.arg(searchMode, c("startsBetween", "overlap"))

    ##### delete this block once upstream supports the tsLastModified parameter for api/tags/search

    if (! is.null(tsLastModified))
        return (data.frame())

    ##### end of block to delete

    colMap = c(
        "tagID" = "id",
        "projectID" = "projectID",
        "mfgID" = "mfgID",
        "dateBin" = "dateBin",
        "type" = "type",
        "codeSet" = "codeSet",
        "manufacturer" = "manufacturer",
        "model" = "model",
        "lifeSpan" = "lifeSpan",
        "nomFreq" = "nomFreq",
        "offsetFreq" = "offsetFreq",
        "period" = "period",
        "periodSD" = "periodSD",
        "pulseLen" = "pulseLen",
        "param1" = "param1",
        "param2" = "param2",
        "param3" = "param3",
        "param4" = "param4",
        "param5" = "param5",
        "param6" = "param6",
        "param7" = "param7",
        "param8" = "param8",
        "tsSG" = "tsSG",
        "approved" = "approved",
        "deployID" = "deployID",
        "status" = "status",
        "tsStart" = "tsStart",
        "tsEnd" = "tsEnd",
        "deferSec" = "deferSec",
        "speciesID" = "speciesID",
        "markerNumber" = "markerNumber",
        "markerType" = "markerType",
        "latitude" = "latitude",
        "longitude" = "longitude",
        "elevation" = "elevation",
        "comments" = "comments"
    )

    mot = motusQuery(MOTUS_API_SEARCH_TAGS, requestType="get",
               list(
                   projectID       = projectID,
                   tsStart         = tsStart,
                   tsEnd           = tsEnd,
                   status          = status,
                   searchMode      = searchMode,
                   mfgID           = mfgID,
                   tsLastModified  = tsLastModified
               ), ...)

    if (! isTRUE(nrow(mot) > 0))
        return(NULL)

    ## remove "TEST" records, which aren't real tags
    mot = subset(mot, ! grepl("^TEST|^999", mfgID, perl=TRUE))

    ## grab columns we want, fillling in NA for any which are missing
    rv = data.frame('.ignore'=seq.int(length=nrow(mot)))

    for(i in seq(along=colMap))
        rv[[names(colMap)[i]]] = if (is.null(mot[[colMap[i]]])) NA else mot[[colMap[i]]]

    rv['.ignore'] = NULL
    return(rv)
}
