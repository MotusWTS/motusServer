#' update metadata for a set of tags
#'
#' These tags might be newly registered, or grabbed from motus.org
#' when refreshing the metadata cache.  Either way, they might be new
#' tags and/or have new or modified deployments.  After cleaning up
#' registration and deployment info for the tags, this function
#' updates the metadata cache (including the derived \code{events}
#' table) and its slim copy in the Motus mariaDB, and commits any
#' changes to the metadata-history repo.
#'
#' @param t: data.frame of tags, as returned by motusSearchTags()
#'
#' @param meta: safeSQL object to metadata DB; default: the global
#' variable \code{MetaDB}
#'
#' @param p: data.frame of projects, as returned by motusListProjects()
#' default: meta("select * from projs")
#'
#' @param fixBI: logical scalar; should burst intervals be corrected?
#' default: FALSE
#'
#' @return TRUE on success.  Generates an error on failure.
#'
#' @note: this function \emph{must} be called within an EXCLUSIVE transaction on
#'     \code{meta}.  This is to ensure that changes to the \code{tags} and
#'     \code{events} tables are atomic with respect to the tag finder
#'     (`find_tags_motus`) program, so that the latter can record the
#'     commit hash from the metadata-history that corresponds to the
#'     metadata it is using.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

updateMetadataForTags = function(t, meta=MetaDB, p = meta("select * from projs"), fixBI=FALSE) {

    ## clean up tag registrations (only runs on server with access to full Lotek codeset)
    ## creates tables "tags" and "events" from the first parameter
    ## and records tags table to the metadata history repo

    t = cleanTagRegistrations(t, meta)

    ## add a fullID label for each tagDep
    t$fullID = sprintf("%s#%s:%.1f@%g", p$label[match(t$projectID, p$id)], t$mfgID, t$period, t$nomFreq)
    t = t[, c(1:2, match("deployID", names(t)): ncol(t))]

    ## write just the deployment portion of the records to tagDeps
    ## first writing to a temporary table to perform a deployment-closing query
    dbWriteTable(meta$con, "tmpTagDeps", t, overwrite=TRUE, row.names=FALSE, temporary=TRUE)

    ## End any unterminated deployments of tags which have a later deployment.
    ## The earlier deployment is ended 1 second before the (earliest) later one begins.

    meta("update tmpTagDeps set tsEnd = (select min(t2.tsStart) - 1 from tmpTagDeps as t2 where t2.tsStart > tmpTagDeps.tsStart and tmpTagDeps.tagID=t2.tagID) where tsEnd is null and tsStart is not null");

    ## Delete existing deployment records for these tags then
    ## copy from tmpTagDeps.

    meta("delete from tagDeps where tagID in (select distinct tagID from tmpTagDeps)")
    meta("insert into tagDeps select * from tmpTagDeps")

    ## update slim copy of tag deps in mysql database
    openMotusDB()
    dbWriteTable(MotusDB$con, "tmpTagDeps", dbGetQuery(meta$con, "select projectID, tagID as motusTagID, tsStart, tsEnd from tmpTagDeps"),
                 row.names=FALSE, overwrite=TRUE)
    MotusDB("delete from tagDeps where motusTagID in (select distinct motusTagID from tmpTagDeps)")
    MotusDB("insert into tagDeps select * from tmpTagDeps")
    MotusDB("drop table tmpTagDeps")

    ## write tagDeps table into the metadata history repo
    write.csv(dbGetQuery(meta$con, "
select
   tagID,
   projectID,
   tsStart,
   tsEnd,
   tsStartCode,
   tsEndCode
from
   tagDeps
order by
   tagID,
   tsStart
"
),
file.path(MOTUS_PATH$METADATA_HISTORY, "tag_deployments.csv"), row.names=FALSE)

    return (TRUE)
}
