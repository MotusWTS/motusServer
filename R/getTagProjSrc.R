#' Get the src_sqlite for a tag project database given its project ID
#'
#' tag project database files are stored in a single directory, and
#' have names like "proj-123.motus"
#'
#' @param projectID motus project ID
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{MOTUS_PATH$TAG_PROJ}
#'
#' @return a src_sqlite for the receiver; if the receiver is new, this database
#' will be empty, but have the correct schema.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getTagProjSrc = function(projectID, dbdir = MOTUS_PATH$TAG_PROJ) {
    src = src_sqlite(file.path(dbdir, paste0("proj-", projectID, ".motus")), TRUE)
    ensureTagProjDB(src, projectID=projectID)
    return(src)
}
