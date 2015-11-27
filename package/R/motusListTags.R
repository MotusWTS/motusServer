#' return a list of all motus tags
#'
#' @param projectID: integer scalar; motus internal project ID
#'
#' @param year: integer scalar; year of tag registration
#'
#' @param mfgID: character scalar; typically a small integer.
#'
#' @param macAddress: character; 12 hex digits in lower case; MAC
#'     address of 1st ethernet adapter on sensor; used to distinguish
#'     between sensors with the same serialNo value (e.g. beaglebone
#'     blacks made by CircuitCo and Element14 can have the same serial
#'     number, but their MAC addresses are unique)
#'
#' @param ...: additional parameters to motusQuery()
#'
#' @return the list of motus tags registered in the given year to the
#'     given project.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListTags = function(projectID, year = NULL, mfgID = NULL, ...) {
    motusQuery(MOTUS_API_LIST_TAGS, requestType="get",
               list(
                   projectID = projectID,
                   year      = year,
                   mfgID     = mfgID
               ), ...)
}
