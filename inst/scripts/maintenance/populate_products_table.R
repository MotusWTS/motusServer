#!/usr/bin/Rscript

## populate the products table in the server jobs database /sgm_local/server.sqlite
## by extracting all products_ items from top level jobs

library(motusServer)
ensureServerDB()

## grab products from jobs where there's more than one

allProds = ServerDB('select jobs.id as jobID, value as URL, json_extract(data, "$.serno") as serno from json_each(json_extract(jobs.data, "$.products_")), jobs where pid is null and json_array_length(jobs.data, "$.products_") > 0')

## jobs with single products store them as string scalars, not an array of length one, so we need a different
## use of the json_* functions:

allProds = rbind(allProds, ServerDB('select jobs.id as jobID, json_extract(jobs.data, "$.products_") as URL, json_extract(data, "$.serno") as serno from jobs where pid is null and json_array_length(jobs.data, "$.products_") == 0 and json_extract(data, "$.products_") != ""'))

allProds = cbind(productID = 1:nrow(allProds), allProds)

## extract project IDs from the URL; they will be first portion looking like `/NNN/`
allProds = cbind(allProds, splitToDF("(?i)(?sx).*/(?<projectID>[0-9]+)/.*", allProds$URL))

## write to Server DB
dbWriteTable(ServerDB$con, "products", allProds, row.names=FALSE, append=TRUE)

cat("Wrote ", nrow(allProds), " products to database.\n")
