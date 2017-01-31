#' create a receiver tag database, for use by the sensorgnome on-board
#' tag detector
#'
#' This lets users see live detections of their tags in the field.
#'
#' @param projectID integer motus project ID
#'
#' @param dateBin character vector of length 1 or 2; gives the allowed
#'     value(s) of dateBin fields, for filtering the tag set from the
#'     given project.  Only tags with dateBin in the range given by
#'     \code{range(dateBin)} are included in the resulting database.
#'
#' @param path folder to which to write the tag database file.  It
#'     will be called
#'     'project_XXX_YYYY-Q_(YYYY-Q)?_tag_database.sqlite' where XXX is
#'     the projectID, and the one or two YYYY-Q parts give the dateBin
#'     or range of dateBins of the tags included.  Default:
#'     \code{MOTUS_PATH$TAGS}
#'
#' @return the full path to the tag database, or NULL if no tags were written.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

createRecvTagDB = function(projectID, dateBin, path = MOTUS_PATH$TAGS) {

    dateBinRange = range(dateBin)

    ## read directly from motus using the API, because in typical case, this function is
    ## called immediately after registering new tags, and so the locally cached tag DB cache
    ## is stale

    tags = motusSearchTags(projectID=projectID) %>% subset( dateBin >= dateBinRange[1] & dateBin <= dateBinRange[2])

    if (! isTRUE(nrow(tags) > 0))
        stop("No tags found for project ", projectID, " with dateBin in ", paste(dateBin, collapse="-"))

    dbFile = file.path(path, sprintf("project_%d_%s_tag_database.sqlite", projectID, paste0(dateBin, collapse="_")))

    ## lookup project label
    meta = safeSQL(getMotusMetaDB())
    label = meta("select label from projs where id=:id", id=projectID)[[1]]
    if (! isTRUE(nchar(label) > 0))
        label = sprintf("project_%d", projectID)

    ## work from temporary in-memory database
    con = dbConnect(SQLite(), ":memory:")
    dbWriteTable(con, "tags", tags)

    ## attach output database on disk
    dbGetQuery(con, sprintf("attach database '%s' as d", dbFile))

    ## in case we've tried doing this before
    dbGetQuery(con, "drop table if exists d.tags")

    ## create output database table from temp table
    dbGetQuery(con, sprintf("create table d.tags as select '%s' as proj , mfgID as id,round( nomFreq, 3) as tagFreq,round(nomFreq-0.004,3)as fcdFreq, param1 as g1, param2 as g2, param3 as  g3,period as bi, offsetFreq as dfreq , param4 as `g1.sd`, param5 as `g2.sd`, param6 as `g3.sd`, periodSD as `bi.sd`, 0.0 as `dfreq.sd`, 'uploaded file' as filename, codeSet as codeset from tags", label))

    dbGetQuery(con, "detach database d")
    dbDisconnect(con)
    return(dbFile)
}
