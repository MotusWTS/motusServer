#!/usr/bin/Rscript
##
## Usage: register_failed_uploads.R minDate
##
## where minDate is a lubridate::ymd_hms compatible date/time
##
##   see https://github.com/jbrzusto/motusServer/issues/318
##   and https://github.com/jbrzusto/TO_DO/issues/172
##
## For uploads that failed due to the above or other issues, the file was uploaded
## to /sgm/uploads/partial, but then:
## - corresponding entries to the ProjectSend database tables were not made
## - the file was not processed by motusServer code

## This script fixes the problem like so:
##
## - make these entries in the `uploads` (ProjectSend) database:
##    - table ul_files: record for the file
##    - table ul_actions_log: record for uploading the file
## - print the list of user IDs who need to be notified that their uploaded files have
## to be assigned to projects and submitted for processing.

library(motusServer)

ARGV = commandArgs(TRUE)

minDate = NA
if (length(ARGV) > 0) {
    ## user specified date time
    minDate = lubridate::ymd_hms(ARGV[1])
    if (is.na(minDate)) {
        ## maybe user only gave date
        minDate = lubridate::ymd_hms(paste0(ARGV[1], "T00:00:00"))
    }
}

## Get the names of files that didn't register

f = data.frame(path=dir(MOTUS_PATH$UPLOADS_PARTIAL, full.names=TRUE), stringsAsFactors=FALSE)
f = subset(f, ! grepl("\\.part$", f$path))

f$date = NA
f$motus_user_ID = NA
parts = strsplit(basename(f$path), "_")
for (i in seq_len(nrow(f))) {
    f[i, c("date", "motus_user_ID")] = list(lubridate::ymd_hms(parts[[i]][2]), as.integer(parts[[i]][1]))
}

f = subset(f, !is.na(date) & !is.na(motus_user_ID))
if (!is.na(minDate))
    f = subset(f, date >= minDate)

## calculate hashes and see whether these files have already been uploaded
f$hash = as.character(NA)
for (i in seq_len(nrow(f))) {
    f$hash[i] = strsplit(safeSys("sha1sum", f$path[i]), " ")[[1]][1]
}
## drop files with the same hash
f = subset(f, ! duplicated(f$hash))

## check against DB for duplicates
drop = rep(FALSE, nrow(f))
openMotusDB()
for (i in seq_len(nrow(f))) {
    drop[i] = isTRUE(MotusDB("select count(*) from uploads where sha1=%s", f$hash[i])[[1]] > 0)
}
f = f[! drop, ]

f = subset(f, ! is.na(motus_user_ID))

if (nrow(f) == 0) {
    stop("No files to process.")
}

f$url = f$path
f$motus_project_ID = 0
f$expiry_date = format(Sys.time() + 24*3600*365, "%Y-%m-%d %H:%M:%S")
f$public_allow = 0
f$filename = basename(f$path)
f$size = file.size(f$path)
openMotusDB()
options(Encoding="UTF-8")

for (i in 1:nrow(f)) {
    MotusDB("insert into uploads.ul_files (url, filename, expiry_date, public_allow, motus_project_ID, size, motus_user_ID, description, uploader)
     values (%s, %s, %s, %d, %d, %f, %d, '', '')",
     f$filename[i], f$filename[i], f$expiry_date[i], f$public_allow[i], 0, f$size[i], f$motus_user_ID[i])
}
cat("These users have files waiting to be assigned to projects and submitted:\n")
cat(deparse(as.numeric(unique(f$motus_user_ID))))
cat("\n")
