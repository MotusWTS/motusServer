#' return the URL to the download site for a project
#'
#' @param port projectID integer scalar; motus project ID
#'
#' @param isTesting logical scalar; if TRUE, the URL is to
#' the testing hierarchy of web products, rather than
#' the usual one.  Default:  FALSE
#'
#' @return character scalar giving URL of download site
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getDownloadURL = function(projectID, isTesting) {
    if (!isTRUE(projectID > 0))
        projectID = 0
    sprintf(if (isTesting) MOTUS_TEST_DOWNLOAD_URL_FMT else MOTUS_DOWNLOAD_URL_FMT, projectID)
}
