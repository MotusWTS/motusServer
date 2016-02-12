#' return a list of all motus sensors
#'
#' @param projectID: integer; motus internal project ID
#'
#' @param year: integer; year of sensor deployment
#'
#' @param serialNo: character; serial "number" for sensor, if a
#' specific sensor is sought.
#'
#' @param macAddress: character; 12 hex digits in lower case; MAC
#'     address of 1st ethernet adapter on sensor; used to distinguish
#'     between sensors with the same serialNo value (e.g. beaglebone
#'     blacks made by CircuitCo and Element14 can have the same serial
#'     number, but their MAC addresses are unique)
#'
#' @param ...: additional parameters to motusQuery()
#'
#' @return the list of motus sensors.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListSensors = function(projectID = NULL, year = NULL, serialNo=NULL, macAddress=NULL, ...) {
    motusQuery(MOTUS_API_LIST_SENSORS, requestType="get",
               list(
                   projectID  = projectID,
                   year       = year,
                   serialNo   = serialNo,
                   macAddress = macAddress
               ), ...)
}
