#' get a set of tags.
#'
#' This function returns data_frames of tags.  These can come
#' from receiver databases or tag databases.  Meta data can
#' be linked when available.
#' 
#' @param src dplyr src_sqlite to database.  This must have tables
#' batches, hits, runs.
#'
#' @param srcT dplyr src to database with "tags" table.  Default: \code{src}
#'
#' @param srcP dplyr src to database with "projects" table.  Default: \code{src}
#'
#' @param srcS dplyr src to database with "species" table.  Default: \code{src}
#'
#' @return a data_frame of tag detections
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

tags = function(src, srcT=src, srcP=src, srcS=src) {
    t = tbl(src, "hits") %>%   ## detections
        left_join (tbl(src, "runs"), by=c(runID="runID"))   %>% ## linked to their runs of detections
        
        left_join (tbl(srcT,"tags") %>% select(tagID, mfgID, speciesID,projectID, nomFreq, period), by=c(motusTagID="tagID"), copy=TRUE) %>% ## linked to their tag metadata
        left_join (tbl(srcS, "species"), by=c(speciesID="id"), copy=TRUE) %>%  ## linked to the species code
        left_join (tbl(srcP, "projects"), by=c(projectID="id"), copy=TRUE) %>% ## linked to the project code
        mutate_ (fullID = ~printf("%s#%s@%g:%.1f", projCode, mfgID, nomFreq, period)) ## can't seem to do this in dplyr-style
    return(t)
}
    
