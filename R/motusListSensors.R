#' return a list of all motus sensors
#'
#' @param projectID: integer; motus internal project ID
#'
#' @param year: integer; year of sensor deployment
#'
#' @param serialNo: character; serial "number" for sensor, if a
#' specific sensor is sought.
#'
#' @param ...: additional parameters to motusQuery()
#'
#' @return the list of motus sensors.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListSensors = function(projectID = NULL, year = NULL, serialNo=NULL, ...) {
    par = list(
        projectID  = projectID,
        year       = year,
        serialNo   = serialNo
        )

    if (! is.null(macAddress))
    motusQuery(MOTUS_API_LIST_SENSORS, requestType="get",
               par,
                ...)
}
