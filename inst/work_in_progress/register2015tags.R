#!/usr/bin/Rscript

library(motus)

tagMap = "~/proj/motus/2015_sensorgnome_tag_map.csv" %>%
    read.csv(as.is=TRUE) %>% as.tbl

ts2015 = ymd("2015-01-01")

tags = tbl(src_sqlite("/SG/2015_tags.sqlite"), "tags") %>%
    left_join(tagMap, by=c("tagFreq" = "sgTagFreq", "proj"="sgProj", "id"="sgID" ), copy=TRUE) %>%
    arrange(proj, id) %>%
    collect() %>%
    mutate(offsetFreq = dfreq+(fcdFreq - tagFreq) * 1000,
           mfgID = sprintf("%.1f", id),
           codeSet = ifelse (proj=="Helgoland" | (proj == "LPBats" & id %in% c(21, 32, 33, 41, 55, 69, 85, 98, 122, 137, 145, 171, 177, 182, 191)), "Lotek-3" ,"Lotek-4"),
           regts = file.info(filename)$mtime
           )
tags$regts[is.na(tags$regts)] = ts2015

tags = tags %>% mutate(dateBin = sprintf("%4d-%1d", year(regts), ceiling(month(regts)/3)))

# replace NA with -1 in those columns where it sometimes occurs

tags$bi.sd[is.na(tags$bi.sd)]       = -1
tags$dfreq.sd[is.na(tags$dfreq.sd)] = -1
tags$g1.sd[is.na(tags$g1.sd)]       = -1
tags$g2.sd[is.na(tags$g2.sd)]       = -1
tags$g3.sd[is.na(tags$g3.sd)]       = -1

# generate tag spreadsheet

## expTags = tags %>% select(proj, motusID, motusName, mfgID, bi, filename) %>% rename(sgProj=proj, ID=mfgID, BI=bi) %>%
##     mutate(regDate = format(file.info(filename)$mtime, "%Y-%b-%d")) %>% select (-filename)

## expTags$BI = round(expTags$BI, 1)
## write.csv(as.data.frame(expTags), "~/proj/motus/2015_sg_tags.csv", row.names=FALSE)


for (i in 1:nrow(tags)) {
    if (is.na(tags$motusProjID[i]))
        next
    tryCatch({
        motusRegisterTag(
            projectID    = tags$motusProjID[i],
            mfgID        = tags$mfgID[i],
            manufacturer = "Lotek",
            type         = "ID",
            codeSet      = tags$codeSet[i],
            offsetFreq   = tags$offsetFreq[i],
            period       = tags$bi[i],
            periodSD     = tags$bi.sd[i],
            pulseLen     = 2.5,
            param1       = tags$g1[i],
            param2       = tags$g2[i],
            param3       = tags$g3[i],
            param4       = tags$g1.sd[i],
            param5       = tags$g2.sd[i],
            param6       = tags$g3.sd[i],
            paramType    = 1,
            ts           = as.numeric(tags$regts[i]),
            nomFreq      = tags$tagFreq[i],
            dateBin      = tags$dateBin[i]
        )
    }, error = function(e) {
        cat("Error: motusID=", tags$motusID[i], "; mfgID=", tags$mfgID[i], " ", as.character(e),"\n")
    })
}

