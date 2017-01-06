#!/usr/bin/Rscript

# move all raw sensorgnome files to /sgm/file_repo/SERNO/...

# This script must be run as root

LINKS="/sgm/file_symlinks"
REPO="/sgm/file_repo"

setwd(LINKS)

## get all serial numbers for which we have files
ss = dir(".")

for (s in ss) {
    fsrc = Sys.readlink(dir(file.path(LINKS, s), full.names=TRUE))
    fdst = file.path(REPO, s, basename(fsrc))
    fi = file.info(fsrc)

    ## move files in decreasing order by size, to ensure we have the longest
    ## version of any given file
    ord = order(fi$size, decreasing=TRUE)
    for (i in ord) {
        system2("/bin/mv", shQuote(c(fsrc[i], fdst[i])))
    }
}
