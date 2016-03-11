#' get a set of tags.
#'
#' This function returns data_frames of tags.  These can come
#' from receiver databases or tag databases.  Meta data can
#' be linked when available.
#' 
#' @param src dplyr src_sqlite to database.  This must have tables
#' batches, hits, runs, tags, projects, species.
#'
#' @return a data_frame of tag detections
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm

tags = function(src) {
    return (
        tbl(src, "hits") %>%   ## detections
        left_join (tbl(src, "runs"), by=c(runID="runID"))   %>% ## linked to their runs of detections

        left_join (tbl(src,"tags"), by=c(motusTagID="tagID")) %>% ## linked to their tag metadata
        left_join (tbl(src, "species"), by=c(speciesID="id")) %>%  ## linked to the species code
        left_join (tbl(src, "projects"), by=c(projectID="id")) ## linked to the project code
        )
}
    
