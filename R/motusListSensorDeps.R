#' return a list motus sensor deployments for a project
#'
#' @param projectID: integer; motus internal project ID
#'
#' @param ...: additional parameters to motusQuery()
#'
#' @return the list of sensor deployments for this project; a data.frame
#' with these columns:
#' \itemize{
#' \item id
#' \item serno
#' \item receiverType
#' \item deviceID
#' \item macAddress
#' \item status
#' \item deployID
#' \item name
#' \item fixtureType
#' \item latitude
#' \item longitude
#' \item isMobile
#' \item tsStart
#' \item tsEnd
#' \item projectID
#' \item elevation
#' \item antennas; a list column, whose elements are themselves data.frames giving antenna deployments for each receiver
#' }
#'
#' or NULL if there are no deployments for this project.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListSensorDeps = function(projectID = NULL, ...) {
    colsNeeded =  c("id", "serno", "receiverType", "deviceID", "macAddress", "status", "deployID", "name", "fixtureType", "latitude", "longitude", "isMobile", "tsStart", "tsEnd", "projectID", "elevation", "antennas")

    rv = motusQuery(MOTUS_API_LIST_SENSOR_DEPS, requestType="get",
               list(
                   projectID  = projectID
               ), ...)
    if (!isTRUE(nrow(rv) > 0))
        return(NULL)

    ## fill in projectID
    rv$projectID = projectID

    ## fill in any missing columns, then return in stated order
    for (col in colsNeeded) {
        if (is.null(rv[[col]]))
            rv[[col]] = NA
    }
    return(rv[, colsNeeded])
}
