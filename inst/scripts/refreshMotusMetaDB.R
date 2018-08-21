#!/usr/bin/Rscript
##
## refresh the motus metadata cache by API calls to motus.org
##
## Run once per day from this crontab:

## # Run at 8:30 GMT (4:30 or 5:30 AM Atlantic time)
## 30 8     * * *     sg  /sgm_local/bin/refreshMotusMetaDB.R

suppressMessages(suppressWarnings(library(motusServer)))
## open jobs and master databases
invisible({
    ## we don't want output unless there is a problem, as output
    ## is emailed to addresses in MOTUS_ADMIN_EMAIL, defined
    ## in motusConstants.R

    ensureServerDB()
    openMotusDB()

    ## force environment symbol USER to be set, which cron doesn't do
    ## this is required for ltGetCodeset()
    ## see https://github.com/jbrzusto/motusServer/issues/383

    Sys.setenv(USER="sg")
    x = refreshMotusMetaDBCache()
})

if (! all(x)) {
    cat(sprintf("Error refreshing motus metadata cache!\nThese items failed: %s",
                paste(names(x)[! x], collapse=", ")))
}
