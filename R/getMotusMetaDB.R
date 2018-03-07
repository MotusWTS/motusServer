#' Get a safeSQL connection to the cached copy of the motus metadata.
#'
#' @details If there is no cached copy, then force its creation
#' via \link{\code{refreshMotusMetaDBCache()}}
#' Normally, this is done regularly by a cron job.
#'
#' This function should be called once by each \code{*Server()} process.
#'
#' @return a \link{\{code{safeSQL}} connection to the database.
#' This value is also stored in the symbol `MetaDB` in the global
#' environment.
#'
#' It will have these tables:
#'
#' \strong{tags:}
#' \itemize{
#' \item tagID motus tag ID
#' \item projectID
#' \item mfgID
#' \item dateBin
#' \item type
#' \item codeSet Manufacturer codeset name
#' \item manufacturer
#' \item model
#' \item lifeSpan in days
#' \item nomFreq  nominal frequency, in MHz e.g. 166.38
#' \item offsetFreq offset from nominal, in kHz
#' \item period  burst interval
#' \item periodSD
#' \item pulseLen
#' \item param1
#' \item param2
#' \item param3
#' \item param4
#' \item param5
#' \item param6
#' \item param7
#' \item param8
#' \item tsSG
#' \item approved
#' }
#'
#' \strong{tagDeps:}
#' \itemize{
#' \item tagID
#' \item deployID
#' \item status
#' \item tsStart
#' \item tsEnd
#' \item deferSec
#' \item speciesID
#' \item markerNumber
#' \item markerType
#' \item latitude
#' \item longitude
#' \item elevation
#' \item comments      a JSON-formatted character string of additional properties
#' \item fullID  tag formatted as
#' }
#'
#' \strong{events:}
#' \itemize{
#' \item ts    timestamp for event
#' \item tagID motus tag ID for event
#' \item event integer: 1 is activation; 0 is deactivation
#' }
#'
#'
#' \strong{species:}
#' \itemize{
#' \item id  integer species ID
#' \item english english species name
#' \item french french species name
#' \item scientific species name
#' \item group informal taxonomic group
#' \item sort taxonomic sorting key
#' }
#'
#'
#'
#'\strong{recvDeps:}
#' \itemize{
#' \item id   receiver ID ?? how does this differ from motus device ID
#' \item serno  receiver serial number
#' \item receiverType
#' \item deviceID motus device ID
#' \item macAddress
#' \item status
#' \item deployID
#' \item name
#' \item fixtureType
#' \item latitude
#' \item longitude
#' \item isMobile
#' \item tsStart
#' \item tsEnd
#' }
#'
#' \strong{recvGPS:}
#' This table is used to look up GPS fixes for a detection.  For a stationary receiver deployment,
#' lat, lon, and elev are the same values as in the recvDeps record.
#' For a mobile receiver deployment, the full set of GPS records for the receiver are given.
#'
#' \itemize{
#' \item deviceID motus receiver ID
#' \item ts timestamp for fix
#' \item lat
#' \item lon
#' \item elev
#' }
#'
#' FIXME: for now, mobile receivers are any with the word "mobile" in
#' the name (ignoring case), or for which isMobile is TRUE, or for
#' which the fixtureType is "Ship".
#'
#' \strong{antDeps:}
#' \itemize{
#' \item deployID receiver deployment ID
#' \item port  which port (USB for SGs; BNC for Lotek) the antenna was plugged into
#' \item antennaType
#' \item bearing magnetic compass bearing of antenna main axis
#' \item heightMeters height of antenna above ground
#' }
#'
#' \strong{projs:}
#' \itemize{
#' \item id motus project ID
#' \item name motus project name
#' \item label short project label for graphs
#' \item tagsPermissions
#' \item sensorsPermissions
#' }
#'
#'
#' \strong{paramOverrides:}
#' \itemize{
#' \item projectID; project ID to which this override applies for all matching receiver deployments
#' \item serno; receiver serial number
#' \item tsStart; starting timestamp for this override
#' \item tsEnd; ending timestamp for this override
#' \item monoBNlow; starting boot session for this override
#' \item monoBNhigh; ending boot session for this override
#' \item progName; program name; e.g. "find_tags_motus"
#' \item paramName; name of parameter; e.g. "default_freq"
#' \item paramVal; value of parameter e.g. 166.38
#' \item why; character vector giving reason for override
#' }
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

getMotusMetaDB = function() {
    ## location we store a cached copy of the motus tag DB
    if (! file.exists(MOTUS_METADB_CACHE))
        refreshMotusMetaDBCache()
    MetaDB <<- safeSQL(MOTUS_METADB_CACHE)
    return(MetaDB)
}
