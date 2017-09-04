#' get the commit hash for the currently-cached motus metadata
#'
#' @return character scalar commit hash, a hex string with 40 characters.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getMetadataHash = function() {
    sub("\n", "", safeSys(paste0("cd ", MOTUS_PATH$METADATA_HISTORY, "; git rev-parse HEAD"), quote=FALSE)[1])
}
