#' return all registered tags for a project
#'
#' The tags are returned as a tbl_df, with some columns given
#' class attributes, and others added for convenience.
#'
#' @param projectID: integer scalar; motus internal project ID
#'
#' @return a dplyr::tbl_df object of tags registered to the given project.
#' This is both a dplyr::tbl and a data.frame, so both data.frame and
#' dplyr methods can be used on it.  Each row corresponds to a tag.
#' The timestamp columns are given the class c("POSIXt", "POSIXct").
#' New columns are added:
#' \enumerate{
#' \item id is set to the numeric equivalent of the manufacturer
#' \item iid is \code{round(id)}, which is the unaltered manufacturer ID
#' as an integer (tags might have been registered with digits after the
#' decimal point to distinguish among those with identical ID but different BI )
#' \item year is set to the year of registration
#' \item iPeriod is the period, rounded to the nearest second.
#' }
#' 
#' If no tags are registered for the project, returns NULL.
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getProjectTags = function(projectID) {
    motusSearchTags(projectID = projectID) %>%
        as.tbl %>%
        mutate(
            ## numeric form of ID
            id = as.numeric(motus$mfgID),
            ## rounded ID, since we will often match by burst interval
            iid = round(id),
            ## give timestamps a useful class
            tsSG     = TS(tsSG),
            tsStart  = TS(tsStart),
            tsEnd    = TS(tsEnd),
            ## registration year
            year     = year(tsSG),
            ## burst interval rounded to integer
            iPeriod = round(period)
        )
}
