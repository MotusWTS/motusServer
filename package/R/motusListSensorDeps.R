#' return a list motus sensor deployments for a project
#'
#' @param projectID: integer; motus internal project ID
#'
#' @param ...: additional parameters to motusQuery()
#'
#' @return the list of sensor deployments for this project
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListSensorDeps = function(projectID = NULL, ...) {
    motusQuery(MOTUS_API_LIST_SENSOR_DEPS, requestType="get",
               list(
                   projectID  = projectID
               ), ...)
}
