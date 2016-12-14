#' Get the motus database of metadata for tags, receivers, projects,
#' and species.
#'
#' @return a path to an sqlite database usable by the \code{tagview} function
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
    cachedDB = "/sgm/cache/motus_meta_db.sqlite"
    oldCachedDB = "/sgm/cache/motus_meta_db_old.sqlite"

    ## if either the cached copy doesn't exist, or it is more than 1 day old,
    ## grab it again

    if (file.exists(cachedDB) && diff(as.numeric(c(file.info(cachedDB)$mtime, Sys.time()))) <= 24 * 3600) {
        return (cachedDB)
    }

    ## open / create the cached DB; because we might be re-populating it via network
    ## API calls to motus.org, allow for a 5 minute busy timeout.
    s = src_sqlite(cachedDB, TRUE)
    dbGetQuery(s$con, "pragma busy_timeout=300000")

    ## if all tables are already present; save this as the older version
    if (all(c("tags", "tagDeps", "events", "species", "projs", "recvDeps", "antDeps", "recvGPS") %in% src_tbls(s))) {
        dbDisconnect(s$con)
        file.rename(cachedDB, oldCachedDB) ## overwrites any existing old copy
        s = src_sqlite(cachedDB, TRUE)
        dbGetQuery(s$con, "pragma busy_timeout=300000")
    }

    ## grab tags
    t = motusSearchTags()

    ## clean up tag registrations (only runs on server with access to full Lotek codeset)
    ## creates tables "tags" and "events" from the first parameter

    t = cleanTagRegistrations(t, s)

    ## grab projects
    p =  motusListProjects()

    ## rename "code" column to "label"
    names(p)[match("code", names(p))] = "label"

    dbWriteTable(s$con, "projs", p, overwrite=TRUE, row.names=FALSE)

    ## add a fullID label for each tagDep
    t$fullID = sprintf("%s#%s:%.1f@%g", p$label[match(t$projectID, p$id)], t$mfgID, t$period, t$nomFreq)

    ## write just the deployment portion of the records to tagDeps
    dbWriteTable(s$con, "tagDeps", t[, c(1:2, match("deployID", names(t)): ncol(t))], overwrite=TRUE, row.names=FALSE)

    ## grab species
    dbWriteTable(s$con, "species", motusListSpecies(), overwrite=TRUE, row.names=FALSE)

    ## grab receivers
    recv = data_frame()
    ant = data_frame()

    ## Note: because the motus query isn't returning fields for which there's no data,
    ## we have to explicitly construct NAs
    for(pid in p$id) {
        if (pid == 0)
            next
        r = motusListSensorDeps(projectID=pid)
        if (isTRUE(nrow(r) > 0)) {
            if ("antennas" %in% names(r)) {
                for (i in 1:nrow(r)) {
                    if (! is.null(r$antennas[[i]])) {
                        ant = bind_rows(ant, cbind(deployID=r$deployID[[i]], r$antennas[[i]]))
                    }
                }
            }
            r$projectID = pid
            r$antennas = NULL
            recv = bind_rows(recv, r)
        }
    }
    recv = recv %>% as.data.frame
    ## workaround until upstream changes format of serial numbers for Lotek receivers
    recv$serno = sub("(SRX600|SRX800|SRX-DL)", "Lotek", perl=TRUE, recv$serno)
    dbWriteTable(s$con, "recvDeps", recv, overwrite=TRUE, row.names=FALSE)
    dbWriteTable(s$con, "antDeps", ant %>% as.data.frame, overwrite=TRUE, row.names=FALSE)

    ## GPS fix table; initially, this contains only a single fix for
    ## each receiver deployment but we'll eventually be filling in
    ## additional fixes for mobile receivers.

    dbWriteTable(s$con, "recvGPS",
                 recv %>% transmute (
                              deviceID=deviceID,
                              ts = tsStart,
                              lat = latitude,
                              lon = longitude,
                              elev = 0 ),
                 overwrite=TRUE, row.names=FALSE)

    ## DEPRECATED: copy paramOverrides table from paramOverrides database until there's a motus
    ## API call to fetch these
    sql = ensureParamOverridesTable()
    dbWriteTable(s$con, "paramOverrides", sql("select * from paramOverrides"), overwrite=TRUE, row.names=FALSE)
    sql(.CLOSE=TRUE)

    dbDisconnect(s$con)

    return (cachedDB)

}
