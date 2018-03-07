#' return the URL to the download site for a project
#'
#' @param projectID [optional] integer scalar motus project ID
#'
#' @param errorJobID [optional] integer scalar job ID
#'
#' @param isTesting logical scalar; if TRUE, the URL is to
#' the testing hierarchy of web products, rather than
#' the usual one.  Default:  FALSE
#'
#' @return character scalar giving URL to:
#' \itemize{
#' \item download site for project, if `projectID` is specified
#' \item or .rds stack dump file for job with errors, if `errorJobID` is specified
#' }
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getDownloadURL = function(projectID, errorJobID, isTesting=FALSE) {
    if (! missing(projectID)) {
        if (!isTRUE(projectID > 0))
            projectID = 0
        path = projectID
    } else if (! missing(errorJobID)) {
        if (!isTRUE(errorJobID > 0))
            stop('invalid errorJobID')
        path = sprintf("errors/%08d.rds", errorJobID)
    }
    sprintf(if (isTesting) MOTUS_TEST_DOWNLOAD_URL_FMT else MOTUS_DOWNLOAD_URL_FMT, path)
}
