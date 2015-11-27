#' return a list of all motus projects
#'
#' @param type: "tag", "sensor", or "both" (the default) Specifies the
#'     type of project to be listed.
#'
#' @param ...: additional parameters to motusQuery()
#'
#' @return the list of motus projects
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListProjects = function(type=c("both", "tag", "sensor"), ...) {
    type = match.arg(type)
    # type can be "tag", "sensor", or "both"
    motusQuery(MOTUS_API_LIST_PROJECTS, requestType="get",
               list(
                   type = type
               ), ...)
}
