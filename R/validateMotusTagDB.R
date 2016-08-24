#' Perform sanity checks on the motus tag database, reporting problems.
#'
#' Mainly, look for duplicated tags.
#' 
#' @return a list of problems found.
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

validateMotusTagDB = function() {
    x = motusSearchTags()

    ## bidirectional duplicate: return TRUE for any non-unique item
    bdup = function(x) duplicated(x) | duplicated(x, fromLast=TRUE)
    
    ## check for non-integer tag IDs (might be okay in the future, but for now these are bogus)
    badID = is.na(as.integer(x$mfgID))

    if (sum(badID) > 0) {
        cat("Bad mfgID in these records:\n")
        print(subset(x, badID))
        x = subset(x, ! badID)
    }

    ## check for tags with multiple records where the project IDs disagree
    mtt = as.tbl(mt)
    xproj = mtt %>% inner_join(mtt, by="tagID") %>% filter(projectID.x != projectID.y)
    if (nrow(xproj) > 0) {
        cat("Tags assigned to multiple projects:\n")
        print((xproj %>% collect) [,1:10])
    }
    
    ## check for identical tags within a project, clumping date bin by year

    twins = mtt %>% mutate(
                      iMfgID = as.integer(mfgID),
                      iPeriod = round(period, 1),
                      iDate = substr(dateBin, 1, 4)
                      )
    twins = twins %>% inner_join(twins, by=c("iMfgID", "iPeriod", "iDate", "projectID")) %>%
        filter(tagID.x < tagID.y) %>% arrange(projectID, iMfgID, iPeriod)

    if (nrow(twins) > 0) {
        cat("Duplicated tags in these records:\n")
        print((twins %>% collect %>% as.data.frame)[,1:12])
        twinIDs = twins %>% select(tagID.x, tagID.y) %>% collect %>% as.data.frame %>% unlist %>% unique
        twinRecCount = mtt %>% filter(tagID %in% twinIDs) %>% group_by(tagID) %>% summarize(count=n()) %>% collect
        cat("These duplicated tags have multiple records:\n")
        print(subset(twinRecCount, count > 1))

        twins = twins %>% select (-iMfgID, -iDate, -iPeriod) %>% collect %>% as.data.frame

        nn = grep("\\.x$", colnames(twins), perl=TRUE, value=TRUE) %>% sub(".x", "", .)
        nnx = paste0(nn, ".x")
        nny = paste0(nn, ".y")

        cat("tagID.x,wins,tagID.y,wins,EQ,NE\n")
        for (i in 1:nrow(twins)) {
            xna = is.na(twins[i, nnx])
            yna = is.na(twins[i, nny])
            cat(twins$tagID.x[i], sum(! xna & yna), twins$tagID.y[i], sum(!yna & xna), sum(!xna & !yna & twins[i, nnx] == twins[i, nny]), sum(!xna & !yna & twins[i, nnx] != twins[i, nny]), sep=",")
            cat("\n")
        }
                
    }

    ## look for duplicated band #s
    dband = mtt %>% inner_join(mtt, by="markerNumber") %>% filter(tagID.x < tagID.y & ! is.na(markerNumber) & markerNumber != "U")
    if (nrow(dband) > 0) {
        cat("There are duplicated marker numbers; not necessarily a problem as a bird could be re-tagged\n")
        dband$mfgID.x = as.integer(dband$mfgID.x)
        dband$mfgID.y = as.integer(dband$mfgID.y)
        dband$period.x = round(dband$period.x, 1)
        dband$period.y = round(dband$period.y, 1)
        class(dband$tsStart.x) = class(dband$tsStart.y) = class(Sys.time())
        print((dband %>% collect %>% as.data.frame)[,c("tagID.x", "tagID.y", "mfgID.x", "mfgID.y", "period.x", "period.y", "markerNumber", "tsStart.x", "tsStart.y", "projectID.x", "projectID.y")])
    }
}
