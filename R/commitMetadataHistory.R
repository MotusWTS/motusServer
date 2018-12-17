#' commit any changes to the metadata history git repo
#'
#' @param meta: safeSQL object to DB containing table \code{meta} to
#'     which the metadata commit hash will be written as a key-value
#'     pair \code{c('hash', hash)}.
#'
#' @return TRUE on success.  Generates an error on failure.
#'
#' @details Any changes to the files in the metadata history git repository
#' are committed and pushed upstream.
#'
#' @note This function uses \code{\link{lockSsymbol('metadata_history')}} to protect
#' access to the git repo, but this function \emph{must} be called within an EXCLUSIVE transaction
#' on \code{meta} that is both begun and committed by the caller.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

commitMetadataHistory = function(meta) {
    ## in case there were any changes, commit them to the repo and push to git hub
    lockSymbol("metadata_history")
    on.exit(lockSymbol("metadata_history", lock=FALSE))

    safeSys(paste0("cd ", MOTUS_PATH$METADATA_HISTORY, "; if ( git commit --no-gpg-sign --author='motus_data_server <sgdata@motus.org>' -a -m 'revised upstream' ); then git push; fi"), quote=FALSE)

    ## grab git commit hash and store in meta db

    map = getMap(meta$con)
    map$hash = sub("\n", "", safeSys(paste0("cd ", MOTUS_PATH$METADATA_HISTORY, "; git rev-parse HEAD"), quote=FALSE)[1])

    return(TRUE)
}
