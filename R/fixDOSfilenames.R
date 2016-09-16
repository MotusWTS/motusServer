#' Correct DOS-style 8.3 filenames into their original long filenames.
#'
#' Some users move SG data files along a route that fails to preserve
#' their long filenames, forcing them into a DOS-style 8.3 filename.
#' Perhaps they are storing raw files in the top level folder of a VFAT
#' filesystem, which limits the total length of filenames in a folder.
#' 
#' In any case, these can be recognized by a tilde \code{~} in the filename.
#'
#' If these files are in a folder where there's at least one original filename,
#' then we can 
#'
#' @param name info
#'
#' @param name info
#'
#' @param name info
#'
#' @param name info
#'
#' @param name info
#'
#' @param name info
#'
#' @return info
#'
#' @note
#'
#' @seealso \link{\code{}}
#' 
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

a = function() {
}
#!/usr/bin/Rscript

## ._(` (

##    fix_8_3_filenames.R

## Search a site's incoming folder for files with clobbered FAT
## filenames.  These will have the form [A-Za-z0-9]{6}~[0-9a-zA-Z].GZ
## Convert these to the correct name, using the most recent receiver serial number
## for the site (from the .sqlite database), the timestamp from the first line
## in the file (the 2nd field is always a timestamp), and a boot count obtained
## by matching the times of files in the database.

## If this script reports any renamed files, you'll need to re-process
## the site using e.g. /SG/code/update_site.R

## Call this script as so:

##   fix_8_3_filenames.R [SITE [PROJECT [YEAR]]]

## If YEAR is not specified, use the current year.

## If PROJECT is not specified, and the current or parent
## directory contains a file called PROJCODE.TXT, then use
## the current or parent directory as the project.

## If SITE is not specified, and the current directory
## contains a file called SITECODE.TXT, then use
## the current directory as the site.

## For now, this only works with files written once the GPS has set the system clock.

## ._(` )

## ARGS = commandArgs(TRUE)
## PATH = getwd()

## library(lubridate)
## library(sensorgnome)

## if (length(ARGS) < 3) {
##     if (file.exists("SITECODE.TXT"))
##         YEAR = as.integer(basename(dirname(dirname(getwd()))))
##     else if (file.exists("PROJCODE.TXT"))
##         YEAR = as.integer(basename(dirname(getwd())))
##     else
##         YEAR = year(Sys.time() - 24*3600*30*3)
## } else {
##     YEAR = as.integer(ARGS[3])
##     if (is.na(YEAR) || YEAR < 2011)
##         stop("Invalid YEAR specified:", YEAR)
## }

## if (length(ARGS) < 2) {
##     if (file.exists("PROJCODE.TXT"))
##         PROJ=basename(getwd())
##     else if (file.exists("../PROJCODE.TXT"))
##         PROJ=basename(dirname(getwd()))
##     else
##         stop("Neither current nor parent directory is an SG project directory")
## } else {
##     PROJ=ARGS[2]
##     if (!file.exists(file.path("/SG/contrib", YEAR, PROJ, "PROJCODE.TXT")))
##         stop("Invalid project specified:", PROJ)
## }

## if (length(ARGS) < 1) {
##     if (file.exists("SITECODE.TXT"))
##         SITE=basename(getwd())
##     else
##         stop("Current directory is not an SG site directory")
## } else {
##     SITE = ARGS[1]
##     if (!file.exists(file.path("/SG/contrib", YEAR, PROJ, SITE, "SITECODE.TXT")))
##         stop("Invalid site specified:", SITE)
## }

## setwd(file.path("/SG/contrib", YEAR, PROJ, SITE))

## bad = dir("incoming", pattern="^[a-zA-Z0-9]+~[0-9].(GZ|TXT)", recursive=TRUE, full.names=TRUE)

## if (length(bad) == 0) {
##    cat("No mangled 8.3 filenames found for ", YEAR, PROJ, SITE, "\n")
##    q("no")
## }

## DBFILE = sprintf("%d_%s_%s.sqlite", YEAR, PROJ, SITE)

## library(RSQLite)
## sql = function(con, query, ...) {
##     return (dbGetQuery(con, sprintf(query, ...)))
## }

## con = dbConnect(RSQLite::SQLite(), DBFILE)

## for (f in bad) {
##    isGZ = grepl("GZ$", f)
##    fc = (if (isGZ) gzfile else file) (f, "r")
##    l = readLines(fc, n=1)
##    close(fc)
##    t = as.numeric(strsplit(l, ",")[[1]][2])
##    ts = structure(t, class=class(Sys.time()))
##    tf = format(ts, "%Y-%m-%dT%H-%M-%OS4Z")
##    ## get latest file before this one
##    finfo = sql(con, "select * from files where ts <= %.4f order by ts desc limit 1", t)
##    bootnum = finfo$bootnum
##    recv = sql(con, "select proj,recv from deployments where depID=%d", finfo$depID)
##    filename = sprintf("%s-%s-%06d-%s-all.txt%s", 
##        recv$proj,
##        recv$recv,
##        bootnum,
##        tf,
##        if (isGZ) ".gz" else "")
##    dest = file.path(dirname(f), filename)
##    file.rename(f, dest)
##    cat("Renamed", basename(f), "to", basename(dest), "\n")
## }
## dbDisconnect(con)
