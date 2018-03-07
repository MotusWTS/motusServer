#!/usr/bin/Rscript

# generate the projAmbig table from tagAmbig and tagDeps
#
# for each entry in tagAmbig, assign ambigProjectID, the unique
# identifier for the projects which might own a detection of that
# ambiguous tag.

library(motusServer)

# open connection to MySQL server
openMotusDB()

# get list of deployment projects

query = "
select distinct * from (
   select
      t1.ambigID   as ambigID,
      u1.projectID as projectID1,
      u2.projectID as projectID2,
      u3.projectID as projectID3,
      u4.projectID as projectID4,
      u5.projectID as projectID5,
      u6.projectID as projectID6
   from
      tagAmbig as t1
      join tagDeps as u1 on t1.motusTagID1=u1.motusTagID
      left join tagDeps as u2 on t1.motusTagID2=u2.motusTagID
      left join tagDeps as u3 on t1.motusTagID3=u3.motusTagID
      left join tagDeps as u4 on t1.motusTagID4=u4.motusTagID
      left join tagDeps as u5 on t1.motusTagID5=u5.motusTagID
      left join tagDeps as u6 on t1.motusTagID6=u6.motusTagID
   )
as t11
"

tagProjAmbig = MotusDB(query)
## sort the project IDs in each record
tagProjAmbig$ambigProjString = NA
for (i in 1:nrow(tagProjAmbig)) {
    tagProjAmbig[i, -1] = sort(unique(as.numeric(tagProjAmbig[i, -1])))[1:(ncol(tagProjAmbig)-1)]
    tagProjAmbig$ambigProjString[i] = with(tagProjAmbig[i,], paste(projectID1, projectID2, projectID3, projectID4, projectID5, projectID6))
}
projAmbig = subset(tagProjAmbig[, -1], ! duplicated(ambigProjString))
projAmbig = projAmbig[order(projAmbig$ambigProjString),]
rownames(projAmbig) = projAmbig$ambigProjString

## assign an ambigProjectID for each unique set of projects

projAmbig$ambigProjectID = - (1:nrow(projAmbig))

## lookup ambigProjectID for each ambiguous tag
tagProjAmbig$ambigProjectID = projAmbig[tagProjAmbig$ambigProjString, "ambigProjectID"]

MotusDB("create temporary table _ambigTagProj (ambigID integer, ambigProjectID integer)")

dbWriteTable(MotusDB$con, "_ambigTagProj", tagProjAmbig[,c("ambigID", "ambigProjectID")], append=TRUE, row.names=FALSE)

MotusDB("
update
   tagAmbig as t1
   join _ambigTagProj as t2 on t1.ambigID = t2.ambigID
set
   t1.ambigProjectID = t2.ambigProjectID
")

dbWriteTable(MotusDB$con, "projAmbig",
             projAmbig[,c(
                 "ambigProjectID",
                 "projectID1",
                 "projectID2",
                 "projectID3",
                 "projectID4",
                 "projectID5",
                 "projectID6")]
               , append=TRUE, row.names=FALSE
)
