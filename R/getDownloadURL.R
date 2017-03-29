#' return the URL to the download site for a project
#'
#' @param port projectID integer scalar; motus project ID
#'
#' @return character scalar giving URL of download site
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getDownloadURL = function(projectID) {
    sprintf(MOTUS_DOWNLOAD_URL_FMT, projectID)
}
