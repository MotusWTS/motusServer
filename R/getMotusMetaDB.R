#' Get the motus database of metadata for tags, receivers, projects,
#' and species.
#'
#' @details If the current copy is more than one day old, we try retrieve
#' a more up to date version from motus.org via their API.
#' For each table X, if the appropriate query fails, we leave X as-is.
#' If the query succeeds succeed, then X is renamed to X_old (after deleting
#' table X_old, if it exists), and the results of the query are written to X.
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

    ## try to lock the cachedDB (by trying to lock its name)
    lockSymbol(cachedDB)

    ## make sure we unlock the receiver DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockSymbol(cachedDB, lock=FALSE))

    ## if the cached DB exists and is less than 1 day old, do nothing

    if (file.exists(cachedDB) && diff(as.numeric(c(file.info(cachedDB)$mtime, Sys.time()))) <= 24 * 3600) {
        return (cachedDB)
    }

    ## make sure the database has correct tables
    safeSys("sqlite3", cachedDB, noQuote="<", system.file("motusMetadataSchema.sql", package="motusServer"))

    ## open / create the cached DB; because we might be re-populating it via network
    ## API calls to motus.org, allow for a 5 minute busy timeout.
    s = src_sqlite(cachedDB, TRUE)
    dbGetQuery(s$con, "pragma busy_timeout=300000")

    ## convenience function to backup existing table T to T_old.
    ## We delete from rather than delete and re-create T, so that
    ## we preserve existence of indexes etc.

    bkup = function(T) {
        try(silent=TRUE, {
            dbGetQuery(s$con, paste0("drop table ", T, "_old"))
        })
        try(silent=TRUE, {
            dbGetQuery(s$con, paste0("create table ", T, "_old as select * from ", T))
            dbGetQuery(s$con, paste0("delete from ", T))
        })
    }

    ## grab tags
    try(silent=TRUE, {
        t = motusSearchTags()

        ## clean up tag registrations (only runs on server with access to full Lotek codeset)
        ## creates tables "tags" and "events" from the first parameter

        t = cleanTagRegistrations(t, s)

        ## grab projects
        p =  motusListProjects()

        ## fill in *something* for missing project labels (first 3 words with underscores)
        fix = is.na(p$label)
        p$label[fix] = unlist(lapply(strsplit(gsub(" - ", " ", p$name[fix]), " ", fixed=TRUE), function(n) paste(head(n, 3), collapse="_")))

        if (nrow(p) > 20) { ## arbitrary sanity check
            bkup("projs")
            dbWriteTable(s$con, "projs", p, append=TRUE, row.names=FALSE)
        }

        ## add a fullID label for each tagDep
        t$fullID = sprintf("%s#%s:%.1f@%g", p$label[match(t$projectID, p$id)], t$mfgID, t$period, t$nomFreq)
        t = t[, c(1:2, match("deployID", names(t)): ncol(t))]

        if (nrow(t) > 1000) { ## arbitrary sanity check
            bkup("tagDeps")
            ## write just the deployment portion of the records to tagDeps
            dbWriteTable(s$con, "tagDeps", t, append=TRUE, row.names=FALSE)

            ## End any unterminated deployments of tags which have a later deployment.
            ## The earlier deployment is ended 1 second before the (earliest) later one begins.

            dbExecute(s$con, "update tagDeps set tsEnd = (select min(t2.tsStart) - 1 from tagDeps as t2 where t2.tsStart > tagDeps.tsStart and tagDeps.tagID=t2.tagID) where tsEnd is null and tsStart is not null");

            ## replace slim copy of tag deps in mysql database
            MotusDB("delete from tagDeps")
            dbWriteTable(MotusDB$con, "tagDeps", dbGetQuery(s$con, "select projectID, tagID as motusTagID, tsStart, tsEnd from tagDeps order by projectID, tagID"),
                         append=TRUE, row.names=FALSE)
            dbExecute(MotusDB$con, "update tagDeps set tsEnd = (select min(t2.tsStart) - 1 from tagDeps as t2 where t2.tsStart > tagDeps.tsStart and tagDeps.tagID=t2.tagID) where tsEnd is null and tsStart is not null");
        }
    })

    ## grab species
    try(silent=TRUE, {
        t = motusListSpecies()
        if (nrow(t) > 1000) { ## arbitrary species check
            bkup("species")
            dbWriteTable(s$con, "species", t[,c("id", "english", "french", "scientific", "group", "sort")], append=TRUE, row.names=FALSE)
        }
    })

    ## grab receivers
    try(silent=TRUE, {
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
                    for (i in seq_len(nrow(r))) {
                        if (isTRUE(nrow(r$antennas[[i]]) > 0)) {
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
        recv$receiverType = ifelse(grepl("^SG-", recv$serno, perl=TRUE), "SENSORGNOME", "LOTEK")
        if (nrow(recv) > 100) { ## arbitrary sanity check
            bkup("recvDeps")
            dbWriteTable(s$con, "recvDeps", recv, append=TRUE, row.names=FALSE)

            ## End any unterminated receiver deployments on receivers which have a later deployment.
            ## The earlier deployment is ended 1 second before the (earliest) later one begins.

            dbGetQuery(s$con, "update recvDeps set tsEnd = (select min(t2.tsStart) - 1 from recvDeps as t2 where t2.tsStart > recvDeps.tsStart and recvDeps.serno=t2.serno) where tsEnd is null and tsStart is not null");

            ## update slim copy of receiver deps in mysql database
            MotusDB("delete from recvDeps")
            dbWriteTable(MotusDB$con, "recvDeps", dbGetQuery(s$con, "select projectID, deviceID, tsStart, tsEnd from recvDeps order by projectID, deviceID"),
                         append=TRUE, row.names=FALSE)
        }

        if (nrow(ant) > 100) { ## arbitrary sanity check
            bkup("antDeps")
            dbWriteTable(s$con, "antDeps", ant %>% as.data.frame, append=TRUE, row.names=FALSE)
        }
    })


    ## GPS fix table; initially, this contains only a single fix for
    ## each receiver deployment but we'll eventually be filling in
    ## additional fixes for mobile receivers.

    try(silent=TRUE, {
        gps = recv %>% transmute (
                           deviceID=deviceID,
                           ts = tsStart,
                           lat = latitude,
                           lon = longitude,
                           elev = 0 )  %>%
            distinct (deviceID, ts)
        if (nrow(gps) > 100) { ## arbitrary sanity check
            bkup("gps")
            dbWriteTable(s$con, "recvGPS", gps, append=TRUE, row.names=FALSE)
        }
    })

    ## DEPRECATED: copy paramOverrides table from paramOverrides database until there's a motus
    ## API call to fetch these
    try(silent=TRUE, {
        sql = ensureParamOverridesTable()
        t = sql("select * from paramOverrides")
        if (nrow(t) > 1) { ## arbitrary sanity check
            bkup("paramOverrides")
            dbWriteTable(s$con, "paramOverrides", t, append=TRUE, row.names=FALSE)
        }
    })

    sql(.CLOSE=TRUE)
    dbDisconnect(s$con)
    return (cachedDB)
}
