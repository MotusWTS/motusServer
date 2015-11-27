#' Process a batch of raw sensorgnome receiver files.  The output
#' goes into the mysql "motus" database.
#'
#' A batch of files are all from the same receiver and boot session.
#' This code queries the motus-wts API for metadata:
#'
#' - receiver ID (based on serial number, and eventually MAC address)
#'
#' - tag database (based on dates and eventually location); list of
#'   all tags to be sought over the period of time covered by the
#'   batch of files.
#'
#' @param files character vector of full paths to all files in batch
#'
#' @param haveTagDeployments boolean scalar: do we have all deployment
#'     data for tags?  If so, the list of tags to be searched for is
#'     obtained from motus based on deployment dates, otherwise, it is
#'     based on registration dates.
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

runSGBatch = function(files, haveTagDeployments) {
    finfo = 
    if (length(unique(finfo$recv)) > 1 || length(unique(finfo$bootnum)) > 1)
        stop("A batch cannot have files from more than one receiver or bootnum.")

    motusRecv = motusListSensors(serialNo = finfo$recv[1])
    if (length(motusRecv) == 0)
        stop("Receiver with serial number ", finfo$recv[1], " has not been registered with motus-wts.rg")
    
    dateSpan = range(finfo$ts)

    if (haveTagDeployments) {
        ## get all tags whose deployment should overlap this timespan
        tags = motusSearchTags(tsStart = as.numeric(dateSpan[1]), tsEnd = as.numeric(dateSpan[2]), searchMode = "overlaps")
    } else {
        ## get all tags registered between 6 months preceding the data batch,
        ## and its end timestamp

        tags = motusSearchTags(regStart = as.numeric(dateSpan[1]) - 6 * 30 * 24 * 3600, regEnd = as.numeric(dateSpan[2]))
    }

    ## generate the required tag database as a data_frame



    tdf = data_frame(
           motusID     = tags$tagID,
           tagFreq     = tags$nomFreq,
           fcdFreq     = tags$nomFreq - 0.004,  ## fixme: not used
           dfreq       = tags$offsetFreq,
           g1          = tags$param1,
           g2          = tags$param2,
           g3          = tags$param3,
           bi          = tags$period
    )

    tdb = src_sqlite(tempfile(fileext=".sqlite"), create=TRUE)

    copy_to(tdb, tdf, "tags")

    ttbl = tbl(tdb, "tags")

    ## force a copy of the database to be sent to disk
    ttbl %>% compute(temporary = FALSE) 

    ##
}
    

    
    

