#!/usr/bin/Rscript
##
## register_failed_uploads.R
##
## see https://github.com/jbrzusto/motusServer/issues/318
##
## For uploads that failed due to the above issue, the file was uploaded
## to /sgm/uploads/partial, but then:
## - corresponding entries to the ProjectSend database tables were not made
## - the file was not processed by motusServer code

## This script fixes the problem like so:
##
## - make these entries in the `uploads` (ProjectSend) database:
##    - table ul_files: record for the file
##    - table ul_actions_log: record for uploading the file

library(motusServer)

## Get the missing files
## delete duplicates by hash

hash = readLines(pipe("cd /sgm/uploads/partial; md5sum *", "r"), encoding="UTF-8")

f = data.frame(
    hash = substring(hash, 1, 32),
    file = substring(hash, 35),
    stringsAsFactors = FALSE
    )

drop = duplicated(f$hash)
##file.remove(f$file[drop])
f = f[! drop,]

## get full path to each file
f$name = file.path(MOTUS_PATH$UPLOADS_PARTIAL, f$file)

## grab userIDs for these uploads, and drop any for which this is NA

f$motus_user_ID = as.integer(sub("_.*", "", basename(f$name)))
f = subset(f, ! is.na(motus_user_ID))

f$url = f$name
f$motus_project_ID = 0
f$expiry_date = format(Sys.time() + 24*3600*365, "%Y-%m-%d %H:%M:%S")
f$public_allow = 0
f$filename = basename(f$name)
f$size = file.size(f$name)
saveRDS(f, "~/register_failed_uploads.rds")
openMotusDB()
options(Encoding="UTF-8")

for (i in 1:nrow(f)) {
    MotusDB("insert into uploads.ul_files (url, filename, expiry_date, public_allow, motus_project_ID, size, motus_user_ID, description, uploader)
     values (%s, %s, %s, %d, %d, %f, %d, '', '')",
     f$filename[i], f$filename[i], f$expiry_date[i], f$public_allow[i], 0, f$size[i], f$motus_user_ID[i])
}
