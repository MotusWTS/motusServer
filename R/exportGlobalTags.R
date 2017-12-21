#' export a global tags view as an old-style globaltags .rds file
#'
#' This function is a stop-gap to allow users to get their full data sets
#' in advance of the full end-user motus R package being available.
#'
#' @param projectID integer scalar; motus project ID
#'
#' @param create if TRUE, recreate the tagProj .sqlite database from scratch;
#' otherwise, use the existing one.
#'
#' @param exportFolder character scalar; default:  \code{MOTUS_PATH$TAG_PROJ}
#'
#' @return no return value; writes a file called "proj_NNN_globaltags.rds" to
#' \code{exportFolder}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'
#' @seealso \code{\link{getGlobalTagsView}}
#'

exportGlobalTags = function(projectID, create=TRUE, exportFolder = MOTUS_PATH$TAG_PROJ) {

    if (create) {
        t = makeTagProjDB(projectID)
    } else {
        t = getTagProjSrc(projectID)
    }
    g = getGlobalTagsView(tagview(t, MOTUS_METADB_CACHE, keep=TRUE))
    d = g %>% collect (n = Inf) %>% as.data.frame

    # perform fixups
    d$posInRun = runningCount(d$runID)

    d$proj = as.factor(d$proj)

    d$tagProj <- as.factor(d$tagProj)

    d$site <- as.factor(d$site)

    d$fullID <- as.factor(d$fullID)

    d$depYear <- as.integer(substr(d$depYear, 1, 4))

    d$id <- as.integer(d$id)

    ## label is now "M." + motus tag ID

    d$label <-as.factor(paste0(d$fullID, " - M.", d$label))

    class(d$ts) = class(Sys.time())

    saveRDS(d, file.path(exportFolder, sprintf("proj-%d_globaltags.rds", projectID)))
}
