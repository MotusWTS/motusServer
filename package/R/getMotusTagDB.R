#' Get the full database of tags from motus for use with the tag finder.
#' 
#' The list of all registered tags is obtained from the motus-wts.org
#' server.  A cleaned-up database suitable for the find_tags_motus
#' program is generated, including an events table which indicates
#' when tags were activated and inactivated.  This allows the database
#' to be used against any receiver dataset, regardless of the dates.
#' 
#' For Lotek coded ID tags, the registrations are cleaned up like so:
#' \itemize{
#'
#' \item empirical gap values are replaced with nominal values from
#' the Lotek codeset
#'
#' \item burst intervals are replaced by the mean of nearby good
#'   values.  Nearby means within 0.05s, and good means no more than
#'   0.0005 s shorter than the longest nearby BI.
#'
#' }
#'
#' Registration problems appear to be mainly from dropped USB packets,
#' when the computer used to make tag recordings has not been able to
#' keep up with the full funcubedongle sampling rate.  The result is
#' overly variable estimates of gap values and burst intervals, with a
#' bias downward from the true values (since dropped packets represent
#' lost time).
#'
#' The tag activation events are generated using these items from the
#' motus database, in order of preference (i.e. the first available
#' item is used):
#'
#' \enumerate{
#' 
#' \item tsStart - the starting date for a tag deployment record;
#' tsStartCode = 1L
#' 
#' \item dateBin - the start of the quarter year in which the tag was
#' expected to be deployed;
#' tsStartCode = 2L
#' 
#' \item ts - the date the tag was registered;
#' tsStartCode = 3L
#'
#' }
#'
#' Tag deactivation events are generated using these items, again
#' in order of preference:
#'
#' \enumerate{
#'
#' \item tsEnd - the ending date for a tag deployment; e.g. if a tag
#' was found, or manually deactivated; tsEndCode = 1L
#'
#' \item tsStart for a different deployment of the same tag; tsEndCode = 2L
#' 
#' \item tsStart + predictTagLifespan(model, BI) * marginOfError 
#' if the tag model is known; tsEndCode = 3L
#' 
#' \item tsStart + predictTagLifespan(guessTagModel(speciesID), BI) * marginOfError
#' if the species is known; tsEndCode = 4L
#'
#' \item 90 days if no other information is available; tsEndCode = 5L
#'
#' }
#'
#' @note: as of 6 April 2016, we're using a lifetime of 700 days for tags in the
#' Taylr 2013 project (gulls)
#'
#' @return path to an sqlite database usable by the tag finder; it will have these tables:
#'
#' \strong{tags:}
#' \itemize{
#' \item tagID      motus tag ID
#' \item nomFreq    nominal frequency, in MHz e.g. 166.38
#' \item offsetFreq offset from nominal, in kHz
#' \item param1     first interpulse gap
#' \item param2     second interpulse gap
#' \item param3     third interpulse gap
#' \item period     burst interval
#' \item mfgID      lotek ID code
#' \item codeSet    Lotek codeset name
#' }
#'
#' \strong{events:}
#' \itemize{
#' \item ts    timestamp for event
#' \item tagID motus tag ID for event
#' \item event integer: 1 is activation; 0 is deactivation
#' }
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

getMotusTagDB = function() {
    ## location we store a cached copy of the motus tag DB
    cachedDB = "/sgm/cached_motus_tag_db.rds"

    ## location we store the cleaned version of the motus tag DB
    cleanedDB = "/sgm/cleaned_motus_tag_db.sqlite"

    ## location we store the as-is version of the motus tag DB
    uncleanedDB = "/sgm/uncleaned_motus_tag_db.sqlite"
    
    have = file.exists(c(cachedDB, cleanedDB))
    info = file.info(c(cachedDB, cleanedDB))

    ## if either the cached copy doesn't exist, or it is more than 1 day old,
    ## grab it again
    
    if (! have[1] || diff(as.numeric(c(info$mtime[1], Sys.time()))) > 24 * 3600) {
        m = motusSearchTags()
        saveRDS(m, cachedDB)
    } else {
        m = readRDS(cachedDB)
    }

    if (all(have) && diff(info$mtime) > 0) {
        ## cleaned DB is more recent than cached copy of motus version,
        ## so we're done.
        return(cleanedDB)
    }

    ## drop project 0, which are not real tags
    
    ## drop project 76, Heikko's Helgoland project: not likely anything more to
    ## do with that one, and they're on @150 MHz, not 166.38

    m = subset(m, projectID != 76 & projectID != 0)
    
    ## add columns we need for lookups
    
    m = as.tbl(m) %>%
        mutate (
            id = as.integer(mfgID),    ## id as bare mfgID, without fractional part and in integer form
            bi = round(period * 20)/20      ## burst interval rounded to 0.05 s
        )
    
    ## cleanup gap values from codesets

    codeSets = c("Lotek-3", "Lotek-4")

    ## tags not in a known codeset are left alone (these might be beepers, e.g.)
    other = m %>% filter_ (~!codeSet %in% codeSets)

    ## clean up gaps
    clean = NULL

    for (cs in codeSets) {
        
        lt = ltGetCodeset(cs)

        clean = clean %>%
            bind_rows(
                m %>% filter_(~codeSet==cs) %>%
                left_join(lt, by=c("id"="id"))
                )
    }

    ## generate a best estimate of precise BI for each rounded (to 0.1s) value

    bi = clean %>% select(bi, period) %>%
        group_by(bi) %>%
        summarise(avgPer=mean(period))

    clean = clean %>% left_join(bi, by="bi")

    badBI = clean %>% filter(abs(avgPer-period) > 0.08) %>% collect
    if ( badBI %>% nrow > 0) {
        cat("Problem; these tags have bad looking BI:\n")
        print(badBI)
        badBI <<- badBI
        stop("go back and revisit tag burst interval cleanup")
    }
    ## copy over better gaps, but not BI for the "uncleaned" database
    unclean = clean %>%
        mutate(param1 = g1, param2 = g2, param3 = g3) %>%
        select(-id, -bi, -g1, -g2, -g3, -avgPer) %>%
        bind_rows(other)
    
    clean = clean %>%
        mutate(param1 = g1, param2 = g2, param3 = g3, period = avgPer) %>%
        select(-id, -bi, -g1, -g2, -g3, -avgPer) %>%
        bind_rows(other)

    ## sanity check on deployment times.  If tsStart and tsEnd are both
    ## specified in the database, make sure tsStart <= tsEnd

    insane = which((! is.na(clean$tsStart)) &
            (! is.na(clean$tsEnd)) &
            clean$tsStart > clean$tsEnd)
    
    if (length(insane) > 0) {
        stop("One or more tag deployments have tsEnd < tsStart; these tags are involved:\n ", paste(clean$tagID[insane], collapse=", "))
    }
    
    ##-------------------- tsStart --------------------
    clean$tsStartCode = 1L
    noTsStart = is.na(clean$tsStart)
    
    ## at worst, we use the registration date
    clean$tsStart[noTsStart] = clean$tsSG[noTsStart]
    clean$tsStartCode[noTsStart] = 3L

    ## if a dateBin was specified, use that
    haveDateBin = noTsStart & ! is.na(clean$dateBin)
    clean$tsStartCode[haveDateBin] = 2L

    clean$tsStart[haveDateBin] = subset(clean, haveDateBin) %>%
        with( paste(substr(dateBin, 1, 4), (as.numeric(substring(dateBin,6)) - 1) * 3 + 1, 1, sep="-")) %>%
        ymd %>% as.numeric


    ##-------------------- tsEnd --------------------
    ## Compute tsEnd for tag deployments which don't have it (i.e. most)
    ## If the tag model is specified, use predictTagLifespan;
    ## If no tag model is specified, use the species to lookup a tag model.
    ## Otherwise, use 90 days.

    clean$tsEndCode = 1L
    dayToSec = 24 * 3600
    
    noTsEnd = is.na(clean$tsEnd)

    ## at worst, use tsStart + 90 days
    clean$tsEnd[noTsEnd] = clean$tsStart[noTsEnd] + 90 * dayToSec

    ## set code for worst case
    clean$tsEndCode[noTsEnd] = 5L
    
    ## see whether a tag model was specified
    haveModel = noTsEnd & ! is.na(clean$model)
    clean$tsEndCode[haveModel] = 3L
        
    ## when the model is missing, see whether a species was specified
    haveSpecies = noTsEnd & ! haveModel & ! is.na(clean$speciesID)
    clean$tsEndCode[haveSpecies] = 4L
    
    if (sum(haveSpecies) > 0) {
        clean$model[haveSpecies] = guessTagModel(clean$speciesID[haveSpecies])
        haveModel = noTsEnd & ! is.na(clean$model)
    }

    ## use the specified or guessed model to estimate lifespan, with 50 % margin of error
    lifeSpan = predictTagLifespan(clean$model[haveModel], clean$period[haveModel])

    clean$tsEnd[haveModel] = clean$tsStart[haveModel] + lifeSpan * dayToSec * 1.5

    ## look for overlapping deployments of a given tag, likely due to
    ## overestimating tsSEnd.  When found, make tsEnd for the earlier
    ## deployment 1s before tsStart for the next.   If we just left them
    ## overlapping like this:

    ##  ------+------------------+---------------+-------------+------ (time)
    ##        |                  |               |             |
    ##     tsStart1          tsStart2          tsEnd1         tsEnd2

    ## then the tag would not be seen as active between tsEnd1 and tsEnd2.
    ## So we correct that situation to this:

    ##  
    ##                        tsEnd1
    ##                          |
    ##  ------+-----------------++-----------------------------+------ (time)
    ##        |                  |                             |
    ##     tsStart1          tsStart2                         tsEnd2

    overlap = clean %>% inner_join (clean, by="tagID") %>%
        filter (tsStart.x < tsStart.y & tsStart.y <= tsEnd.x)

    if (nrow(overlap) > 0) {
        fixtsEnd = overlap %>% mutate (tsEnd.x = tsStart.y - 1) %>%
            transmute (deployID = deployID.x, tsEnd = tsEnd.x)

        clean[match(fixtsEnd$deployID, clean$deployID), "tsEnd"] = fixtsEnd$tsEnd
        clean[match(fixtsEnd$deployID, clean$deployID), "tsEndCode"] = 2L
     }
    
    ## remove duplicates, which are due to multiple deployments
    nodups = subset(clean, ! duplicated(tagID))

    con = dbConnect(SQLite(), cleanedDB)
    dbWriteTable(con, "tags", nodups %>% as.data.frame, overwrite=TRUE)

    ## now create events table
    ## This has the columns: ts, tagID, event (0 or 1)

    tagOn  = clean %>% filter(!is.na(tsStart)) %>% transmute(ts=tsStart, tagID=tagID, event=1L)
    tagOff = clean %>% filter(!is.na(tsEnd))   %>% transmute(ts=tsEnd,   tagID=tagID, event=0L)
    
    events = tagOn %>% bind_rows(tagOff) %>% arrange(ts)
    
    dbWriteTable(con, "events", events %>% as.data.frame, overwrite=TRUE)

    dbGetQuery(con, "create index events_ts on events(ts)")

    dbDisconnect(con)

    return (cleanedDB)
}
