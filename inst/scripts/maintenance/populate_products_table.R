#!/usr/bin/Rscript

## populate the products table in the server jobs database /sgm_local/server.sqlite
## by extracting all products_ items from top level jobs

library(motusServer)
ensureServerDB()

## grab products from jobs where there's more than one

allProds = ServerDB('select jobs.id as jobID, value as URL from json_each(json_extract(jobs.data, "$.products_")), jobs where json_array_length(jobs.data, "$.products_") > 0')

## jobs with single products store them as string scalars, not an array of length one, so we need a different
## use of the json_* functions:

allProds = rbind(allProds, ServerDB('select jobs.id as jobID, json_extract(jobs.data, "$.products_") as URL from jobs where json_array_length(jobs.data, "$.products_") == 0 and json_extract(data, "$.products_") != ""'))

allProds = cbind(productID = 1:nrow(allProds), allProds)

## extract project IDs and serial numbesr from the URLs, which look like "https://sgdata.motus.org/download/PROJECTID/SERNO-..."
## we allow that some rows won't match, because they are for tag databases, not receiver-related files
allProds = cbind(allProds, splitToDF("(?i)(?sx).*/(?<projectID>[0-9]+)/(?<serno>(Lotek-[0-9D]+)|(SG-[0-9A-Z]{12}))?.*", allProds$URL))
allProds$serno[allProds$serno == ""] = NA

## write to Server DB, ensuring columns are ordered correctly
dbWriteTable(ServerDB$con, "products", allProds[,c("productID", "jobID", "URL", "serno", "projectID")], row.names=FALSE, append=TRUE)

cat("Wrote ", nrow(allProds), " products to database.\n")

## jobs where a subjob
