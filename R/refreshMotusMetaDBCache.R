#' Refresh our cache of the motus database of metadata for tags,
#' receivers, projects, and species.
#'
#' This refresh is wrapped in a transaction.  Before the transaction
#' is committed, we commit the git repo version of the DB, and
#' grab that commit hash.
#'
#' For each table X, if the appropriate query fails, we leave X as-is.
#'
#' @return a named logical vector indicating whether the query to update
#' each table succeeded.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

refreshMotusMetaDBCache = function() {
    funName = "refreshMotusMetaDBCache"

    ## shorthand for path to cache
    db = MOTUS_METADB_CACHE

    ## tables updated successfully? assume not

    rv = c(tags            = FALSE,
           tagDeps         = FALSE,
           recvDeps        = FALSE,
           antDeps         = FALSE,
           species         = FALSE,
           projs           = FALSE,
           paramOverrides  = FALSE
           )

    ## try to lock the db (by trying to lock its name)
    lockSymbol(db)

    ## make sure we unlock the meta DB when this function exits, even on error
    ## NB: the runMotusProcessServer script also drops any locks held by a given
    ## processServer after the latter exits.

    on.exit(lockSymbol(db, lock=FALSE))

    ## make sure we have a local copy of the motus-metadata-repo, for tracking changes
    ## to metadata

    if (! file.exists(file.path(MOTUS_PATH$METADATA_HISTORY, ".git"))) {
        safeSys(paste("git clone", MOTUS_METADATA_HISTORY_REPO, MOTUS_PATH$METADATA_HISTORY), quote=FALSE)
    }

    ## create the database if it doesn't exist
    if (! file.exists(db)) {
        ## create the database directly from the schema
        safeSys("sqlite3", db, noQuote="<", system.file("motusMetadataSchema.sql", package="motusServer"))
    }

    ## connect
    meta = safeSQL(db)

    ## begin the update-metadata transaction
    meta("BEGIN EXCLUSIVE TRANSACTION")

    ## grab projects
    p = motusListProjects()
    if (nrow(p) < 20) { ## arbitrary sanity check
        stop("upstream listprojects API failing sanity check")
    }
    ## fill in *something* for missing project labels (first 3 words with underscores)
    fix = is.na(p$label)
    p$label[fix] = unlist(lapply(strsplit(gsub(" - ", " ", p$name[fix]), " ", fixed=TRUE), function(n) paste(head(n, 3), collapse="_")))
    rv["projs"] = TRUE

    ## replace copy of projects
    meta("delete from projs")
    dbWriteTable(meta$con, "projs", p, append=TRUE, row.names=FALSE)

    ## grab tags
    tryCatch({
        t = motusSearchTags()
        if (nrow(t) < 1000) { ## arbitrary sanity check
            stop("upstream searchtags API failing sanity check")
        }
        updateMetadataForTags(t, meta, p=p)
        rv[c("tags", "projs", "tagDeps")] = TRUE
    }, error = function(e) {
        motusLog("%s: tagdeps: %s", funName, as.character(e))
    })

    ## grab species
    tryCatch({
        t = motusListSpecies()
        if (nrow(t) < 1000) { ## arbitrary sanity check
            stop("upstream listspecies API failing sanity check")
        }
        meta("delete from species")
        dbWriteTable(meta$con, "species", t[,c("id", "english", "french", "scientific", "group", "sort")], append=TRUE, row.names=FALSE)
        rv["species"] = TRUE
    }, error = function(e) {
        motusLog("%s: species: %s", funName, as.character(e))
    })

    ## grab receivers
    tryCatch({
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
        recv$receiverType = ifelse(grepl("^SG-", recv$serno, perl=TRUE), "SENSORGNOME", ifelse(grepl("^CTT-", recv$serno, perl=TRUE), "SENSORSTATION", ifelse(grepl("^SEI_", recv$serno, perl=TRUE), "SIGMA8", "LOTEK")))
        if (nrow(recv) < 100 || nrow(ant) < 100) { ## arbitrary sanity check
            stop("upstream listsensordeps API failing sanity check")
        }
        meta("delete from recvDeps")
        dbWriteTable(meta$con, "recvDeps", recv, append=TRUE, row.names=FALSE)
        rv["recvDeps"] = TRUE

        ## End any unterminated receiver deployments on receivers which have a later deployment.
        ## The earlier deployment is ended 1 second before the (earliest) later one begins.

        meta("update recvDeps set tsEnd = (select min(t2.tsStart) - 1 from recvDeps as t2 where t2.tsStart > recvDeps.tsStart and recvDeps.serno=t2.serno) where tsEnd is null and tsStart is not null");

        ## update slim copy of receiver deps in mysql database
        MotusDB("delete from recvDeps")
        slimRecvDeps = dbGetQuery(meta$con, "select projectID, deviceID, tsStart, tsEnd from recvDeps order by projectID, deviceID, tsStart")
        dbWriteTable(MotusDB$con, "recvDeps", slimRecvDeps,
                     append=TRUE, row.names=FALSE)
        write.csv(slimRecvDeps,
                  file.path(MOTUS_PATH$METADATA_HISTORY, "receiver_deployments.csv"), row.names=FALSE)

        meta("delete from antDeps")
        dbWriteTable(meta$con, "antDeps", ant %>% as.data.frame, append=TRUE, row.names=FALSE)
        rv["antDeps"] = TRUE

        ## create GPS fix table
        ## 2017-12-21 FIXME: probably obsolete; used in tagview(), but does anything on the
        ## server side use those coordinates?

        meta("delete from recvGPS")
        meta("insert or ignore into recvGPS select deviceID, tsStart, latitude as lat, longitude as lon, elevation as elev from recvDeps")
    }, error = function(e) {
        motusLog("%s: recvDeps: %s", funName, as.character(e))
    })


    ## DEPRECATED: copy paramOverrides table from paramOverrides database until there's a motus
    ## API call to fetch these
    tryCatch({
        sql = ensureParamOverridesTable()
        t = sql("select * from paramOverrides")
        sql(.CLOSE=TRUE)
        meta("delete from paramOverrides")
        dbWriteTable(meta$con, "paramOverrides", t, append=TRUE, row.names=FALSE)
        rv["paramOverrides"] = TRUE
        write.csv(t[order(t$projectID, t$serno, t$tsStart),],
                  file.path(MOTUS_PATH$METADATA_HISTORY, "parameter_overrides.csv"), row.names=FALSE)
    }, error = function(e) {
        motusLog("%s: paramOverrides: %s", funName, as.character(e))
    })

    ## commit any changes to the git repo that tracks history
    commitMetadataHistory(meta)

    ## and now the moment we've all been waiting for
    meta("COMMIT")
    dbDisconnect(meta$con)

    plotTagTimeline()
    return (rv)
}
