#!/usr/bin/Rscript
#
# make sure every sensorgnome file on the server has been merged


TARGET="/sgm/file_symlinks"

## shell script to generate lists of files from all receivers
##
## SOURCES="/raid3tb /raid5tb"
##
## for s in $SOURCES; do
##     find $s  -type f -size +0 -regextype posix-extended -regex "^.*-[a-zA-Z0-9]{4}*BB[a-zA-Z0-9]{6}-[0-9]{6}-[0-9]{4}-[0-1][0-9]-[0-3][0-9].*txt(.gz)$" >> /tmp/allsgfiles.txt
## done

## for s in $SOURCES; do
##     find $s -type f -size +0 -regextype posix-extended -regex "^.*((DTA)|(dta)$)" >> /tmp/allltfiles.txt
## done

library(motusServer)

sg = readLines("/tmp/allsgfiles.txt")
b = basename(sg)
psg = splitToDF(motusServer:::sgFilenameRegex, b, as.is=TRUE, validOnly=FALSE, guess=FALSE)

ord = order(psg$serno)

## sort by receiver
sg = sg[ord]
psg = psg[ord,]
b = b[ord]
na = which(is.na(psg$serno))
psg = psg[-na,]
sg = sg[-na]
b = b[-na]
psg$serno=paste0("SG-",psg$serno)
psg$serno = as.factor(psg$serno)
for (d in levels(psg$serno))
    dir.create(file.path(TARGET, d))
file.symlink(sg, file.path(TARGET, psg$serno, b))

lt = readLines("/tmp/allltfiles.txt")
b = basename(lt)
for(i in 1:length(lt)) {
    f = lt[i]
    x = readDTA(f)
    dir.create(file.path(TARGET, x$recv))
    file.symlink(f, file.path(TARGET, x$recv, b[i]))
}
