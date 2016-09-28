#' Correct DOS-style 8.3 filenames into their original long filenames.
#' Any files needing renaming are renamed on disk.
#'
#' Some users move SG data files along a route that fails to preserve
#' their long filenames, forcing them into a DOS-style 8.3 filename.
#' Typically, this only happens to a few files per batch, for some reason.
#' Perhaps they are storing raw files in the top level folder of a VFAT
#' filesystem, which limits the total length of filenames in a folder.
#'
#' In any case, these can be recognized by a tilde \code{~} in the
#' filename, and the first two letters of the shortened name will
#' match (case insensitively) the first two letters of the original
#' name.
#'
#' @param f vector of full paths to files
#'
#' @param info data frame of split filename components, which are the
#' named capture groups in \link{\code{sgFilenameRegex}}
#'
#' @return info
#'
#' @note Corrections are performed as so:
#'
#' \itemize{
#'
#' \item if there are files with unaltered long names from exactly one
#' sensorgnome in \code{f}, then the shortened files are assumed to
#' have come from that receiver, and their names are corrected
#' post-hoc using content timestamps.
#'
#' \item otherwise, take the the first two characters of each
#' shortened name and see whether they match (case insensitively) the
#' first two characters of unshortened names of a single receiver.
#' Any shortened names for which that is true are corrected.
#'
#' \item otherwise, for any remaining shortened filenames, we can't
#' tell which receiver(s) the misnamed files belong to, so they are
#' saved in a subfolder of "/sgm/manual" with a "README.TXT" giving
#' details.  FIXME: get first and last timestamps in shortened files
#' and compare to timestamps parsed from full names.
#'
#' }
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

fixDOSfilenames = function(f, info) {
    base = basename(f)
    dos = grepl(MOTUS_DOS_FILENAME_REGEX, base, perl=TRUE)

    if (! any(dos))
        return(info)

    ## FIXME: make this work
    ## if (length(unique(rv$serno)) == 1) {
    ##     f[dos] = fixDOSfilenames(f, dos)
    ##     base[dos] = basename(f[dos])  ##
    ## } else {
    ##     ## look at first two chars of all names; shortened names should have
    ##     ## the same two chars as their original long names, ignoring case.
    ##     ## Those two char prefixes mapping to unique serial numbers among
    ##     ## full names are fixable.

    ##     rv$twoChar = toupper(substr(basename(f), 1, 2))
    ##     map = table(rv$twoChar, rv$serno)
    ##     map = map[apply(map, 1, function(x) sum(x > 0) == 1),]

    ##     ## rows of `map` now map uniquely

    ##     s2 = unique(substr(basename(f[  dos]), 1, 2))
    ##     f2 = unique(substr(basename(f[! dos]), 1, 2))


    ## oops - can't tell what receiver these are from.

    motusLog("Can't determine receiver for files with short names: %s",
             paste(base[dos], collapse="\n   "))
    embroilHuman(f[dos], "Annoying files with shortened names!")
    f = f[! dos]
    base = base[! dos]
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
