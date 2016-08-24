#!/usr/bin/Rscript

._(` (

process_incoming_files.R

Distribute a set of files received from a user into the "incoming"
directories for all sites, based on receiver serial numbers of files
and the correspondence between receivers and projects/sites given
in /SG/YEAR_receiver_serno.sqlite.  Then run update_site.R for each
site for which files were received.

Call this script as so:

  process_incoming_files.R [DIR]

where:

  DIR: if specified, this is the directory from which incoming files are
       taken.  It is searched recursively.  If not specified, the current
       directory is used.  If any .7z, .rar or .zip files are found,
       these are extracted and then moved to /tmp.  This process
       is repeated until only .txt and .txt.gz files remain.
       If processing is successful, the archives in /tmp are deleted.
._(` )

ARGS = commandArgs(TRUE)

NARGS = length(ARGS)

if (NARGS > 1) {
  ._SHOW_INFO()
  quit(save="no")
}

DIR = "."
if (NARGS)
    DIR = ARGS[1]

setwd(DIR)

library(lubridate)

## "current" year.
YEAR = year(Sys.time() - 24*3600*30*3)

## decompress any archives, recursively
done = FALSE

while (! done) {
    archs = dir(DIR, recursive=TRUE, pattern=".*\\.(7z|rar|zip)", full.name=TRUE)
    if (length(archs) == 0) {
        break
    }
    for (a in archs) {
        ## sanitize filename: remove escapes and escape double quotes
        a = gsub("\\", "", a, fixed=TRUE)
        a = gsub("\"", "\\\"", a, fixed=TRUE)
        parts = strsplit(a, ".", fixed=TRUE)
        suffix = tail(parts[[1]], 1)
        switch (suffix,
                "zip" = system(sprintf("unzip -o \"%s\"", a)),
                "7z" = system(sprintf("7z x -y \"%s\"",a)),
                "rar" = system(sprintf("unrar x -o+ \"%s\"", a)),
                stop ("I don't know how to handle downloaded file ", a)
        )
        file.remove(a)
    }
}

## make sure files are writable, and delete stupid extra dirs created by
## operating systems

system("chmod -R u+rw .; find . -iname '*__MACOSX*' -or -iname '*._DS_Store*' -delete")

files = dir(DIR, recursive=TRUE, pattern=".*-all\\.txt(\\.gz)?$", full.name=TRUE)

ith = function(l, i) {
    sapply(l, function(x) x[i])
}

parseFilenames = function(f) {
  ## return a data.frame of components from a vector of SensorGnome filenames
  ## these are:
  ## - site: site code
  ## - recv: receiver ID
  ## - bootnum: boot count
  ## - ts: timestamp embedded in name
  ## - tscode: timestamp code ('P' means before GPS fix, 'Z' means accurate)
  ## - src: 'all' or a port number
  ## - extension: extension of uncompressed file; any ".gz" at the end is discarded
    
  ## sample SG filename:
  ## CANS-1212BB000222-000001-2013-04-08T13-17-07.9270P-all.txt.gz
  ## site  recv        bootnum   ts                     ^ src ext
  ##                                                  |
  ## and the tscode is "P"----------------------------+

  parts = strsplit(f, "-", fixed=TRUE)
  parts = parts[as.logical(lapply(parts, function(x) length(x) == 9))]
  extParts = strsplit(ith(parts, 9), ".", fixed=TRUE)
  rv = data.frame(
               site = ith(parts, 1),
##               sqlproj = gsub("'", "''", ith(parts, 1)),
               recv = ith(parts, 2),
               bootnum = as.integer(ith(parts, 3)),
               ts = as.numeric(strptime(substr(paste(ith(parts, 4), ith(parts, 5), ith(parts, 6), ith(parts, 7), ith(parts, 8), sep="-"), 1, 24), "%Y-%m-%dT%H-%M-%OS", tz="GMT")),
               tscode = substring(ith(parts, 8), nchar(ith(parts, 8))),
               src = ith(extParts, 1),
               ext = ith(extParts, 2)
      )
  return(rv[!is.na(rv$ts), ])
}

## parse filenames into components

fileInfo = parseFilenames(basename(files))

fileInfo$recv = paste("SG-", fileInfo$recv, sep="")

 
## for each serial number, find the site/project with the latest files
## from that receiver
## Do this via sqlite

library(RSQLite)
## get receiver list for this year
con = dbConnect(SQLite(), sprintf("/SG/%d_receiver_serno.sqlite", YEAR))
recvs = dbGetQuery(con, "select * from map")
dbDisconnect(con)

con = dbConnect(RSQLite::SQLite(), ":memory:")
dbWriteTable(con, "recvs", recvs)
dbWriteTable(con, "fileInfo", fileInfo)

## left join trick to get latest row (largest tsHi) for each receiver
dbGetQuery(con, "create table recv2 as select t1.* from recvs as t1 left outer join recvs as t2 on t1.Serno=t2.Serno and t1.tsHi < t2.tsHi where t2.Serno is null")

fileInfo = dbGetQuery(con, "select t1.*,t2.Project as Project,t2.Site as Site from fileInfo as t1 left outer join recv2 as t2 on t1.recv=t2.Serno")

dbDisconnect(con)

fileInfo$dest = sprintf("/SG/contrib/%d/%s/%s/incoming/%s", YEAR, fileInfo$Project , fileInfo$Site, basename(files))

## for each unique project and site, move files, possibly across filesystems, which is why
## we can't just use R's file.rename

srclist = tempfile()
writeLines(files, con=srclist)
dstlist = tempfile()
writeLines(fileInfo$dest, con=dstlist)

## assume no error; we want to process as much as we can without triggering an immediate error just
## because some files couldn't find a home.  However, we have to return an error to the caller,
## in case it uses the return code to decide whether it can delete the temporary directories
## where files were placed.  We don't want to delete those if there are files left.

haveError = FALSE

if (system(sprintf("paste -d \\\\n '%s' '%s' | tr '\\n' '\\000' | xargs -0 -L 2 mv ", srclist, dstlist))) {
    haveError = TRUE
}

for (site in unique(paste(fileInfo$Site, fileInfo$Project, YEAR))) {
    cat("Updating site", site, "\n")
    system(paste("/SG/code/update_site.R", site))
}

if (haveError) {
    stop("error moving (some) files")
}

## TODO: Handle Lotek files:

## lotekFiles = dir(DIR, recursive=TRUE, pattern=".*DAT$", full.name=TRUE)
## if (length(lotekFiles) == 0)
##     q(save="no")

## library(sensorgnome) ## to get readDTA function
## siteList = character(0)
    

  ## For files from Lotek receivers, recv is e.g. SRX600-6312 and extension is DTA.
  ## We rename these files to avoid collisions, since sometimes users don't change
  ## filenames between data dumps.  New names have the form
  ##  
  ##  ?????-SRX600-6312-2016-04-05T13-35-56.DTA
  ## where ???? is the filename supplied by the user (the part before .DTA) and
  ## this is followed by the receiver model, serial number, and latest timestamp
  ## present in the file.
