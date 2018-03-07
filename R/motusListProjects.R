#' return a list of all motus projects
#'
#' @param type: "tag", "sensor", or "both" (the default) Specifies the
#'     type of project to be listed.
#'
#' @param ...: additional parameters to motusQuery()
#'
#' @return the list of motus projects, a data.frame with these columns
#'
#' \itemize{
#' \item id integer; project ID
#' \item name character; long name
#' \item label character; short name for plotting etc.
#' \item tagsPermissions; integer
#' \item sensorsPermissions; integer
#'}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListProjects = function(type=c("both", "tag", "sensor"), ...) {
    colsNeeded = c("id", "name", "label", "tagsPermissions", "sensorsPermissions")
    type = match.arg(type)
    # type can be "tag", "sensor", or "both"
    rv = motusQuery(MOTUS_API_LIST_PROJECTS, requestType="get",
               list(
                   type = type
               ), ...)
    if (! isTRUE(nrow(rv) > 0))
        return(NULL)

    ## rename "code" column to "label", "tagPermissions" -> "tagsPermissions", "sensorPermissions"->"sensorsPermissions"
    ## to match traditional usage

    names(rv)[match(c("code", "tagPermissions", "sensorPermissions"), names(rv))] = c("label", "tagsPermissions", "sensorsPermissions")

    ## fill in any missing columns, then return in stated order
    for (col in colsNeeded) {
        if (is.null(rv[[col]]))
            rv[[col]] = NA
    }
    return(rv[, colsNeeded])
}
