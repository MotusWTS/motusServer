#!/usr/bin/Rscript

library(motus)

pmap = tbl(src_sqlite("/SG/motus_sg.sqlite"), "projectMap") %>%
    filter(year==2014) %>%
    select(projCode, motusID)

ts2014 = ymd("2014-01-01")

tags = tbl(src_sqlite("/SG/2014_tags.sqlite"), "tags") %>%
    left_join(pmap, by=c("proj"="projCode"), copy=TRUE) %>%
    arrange(proj) %>%
    collect() %>%
    mutate(offsetFreq = dfreq+(fcdFreq - tagFreq) * 1000,
           mfgID = sprintf("%.1f", id),
           codeSet = ifelse (proj=="Helgoland", "Lotek-3" ,"Lotek-4"),
           regts = file.info(filename)$mtime
           )
tags$regts[is.na(tags$regts)] = ts2014

tags = tags %>% mutate(dateBin = sprintf("%4d-%1d", year(regts), ceiling(month(regts)/3)))

# replace NA with -1 in those columns where it sometimes occurs

tags$bi_sd[is.na(tags$bi_sd)]       = -1
tags$dfreq_sd[is.na(tags$dfreq_sd)] = -1
tags$g1_sd[is.na(tags$g1_sd)]       = -1
tags$g2_sd[is.na(tags$g2_sd)]       = -1
tags$g3_sd[is.na(tags$g3_sd)]       = -1

for (i in 1:nrow(tags)) {
    motusRegisterTag(
        projectID    = tags$motusID[i],
        mfgID        = tags$mfgID[i],
        manufacturer = "Lotek",
        type         = "ID",
        codeSet      = tags$codeSet[i],
        offsetFreq   = tags$offsetFreq[i],
        period       = tags$bi[i],
        periodSD     = tags$bi_sd[i],
        pulseLen     = 2.5,
        param1       = tags$g1[i],
        param2       = tags$g2[i],
        param3       = tags$g3[i],
        param4       = tags$g1_sd[i],
        param5       = tags$g2_sd[i],
        param6       = tags$g3_sd[i],
        paramType    = 1,
        ts           = as.numeric(tags$regts[i]),
        nomFreq      = tags$tagFreq[i],
        dateBin      = tags$dateBin[i]
        )
}

