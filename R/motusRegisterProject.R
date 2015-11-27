#' register a new motus project
#'
#' @param projectName: character scalar; human-readable name of project
#' 
#' @param ...: additional parameters to motusQuery()
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}


motusRegisterProject = function(projectName,
                            ...
                            ) {
    motusQuery(MOTUS_API_REGISTER_PROJECT, requestType="post",
               list(
                   projectName  = projectName
               ), ...)
}
