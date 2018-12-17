#!/usr/bin/Rscript
#
# Add a view to an sqlite database table under which timestamp columns
# are displayed in human-readable format HHHH-MM-DD HH:MM:SS.XXX

ARGV = commandArgs(TRUE)

if (length(ARGV) == 0 || ARGV[1] == "-h" || ARGV[1] == "--help") {
    cat("Create a view of an sqlite table in which timestamp columns are displayed
         in human readable format. Usage:

   humanize [-t TABLEPAT] [-c COLUMNPAT] [-f FORMAT] DB

where:

   DB - path to sqlite database

   TABLEPAT - pcre-compatible pattern for name of tables to humanize.
   Default: '.*' (i.e. all tables are humanized). Can be present more
   than once to specify multiple table name patterns.  Table with names
   ending in `_` are by default excluded, but can be specified manually.

   COLUMNPAT - pcre-compatible pattern for names of columns to humanize
   default: ^ts([A-Z0-9].*)?$  (i.e. any column starting with 'ts' and
   possibly followed by a camelcased suffix.  Can be present more than
   once to specify multiple patterns.

   FORMAT - sqlite::strftime-compatible timestamp format; default:
   %Y-%m-%d %H:%M:%f

For each matching table with at least one matching column, a view is created
named 'T_' (where 'T' is the original table name) in which each matching
column 'C' is replaced with a call to strftime(FORMAT, 'C', 'unixepoch')
Any original view with the name 'T_' is dropped.

");
    q(save="no")
}

db = NULL
colpat = NULL
tabpat = NULL
format = "%Y-%m-%d %H:%M:%f"

while(isTRUE(substr(ARGV[1], 1, 1) == "-")) {
    switch(ARGV[1],
           "-t" = {
               ARGV = ARGV[-1]
               tabpat = c(tabpat, ARGV[1])
           },
           "-c" = {
               ARGV = ARGV[-1]
               colpat = c(colpat, ARGV[1])
           },
           "-f" = {
               ARGV = ARGV[-1]
               format = ARGV[1]
           },
           {
               stop("Unknown argument: ", ARGV[1])
           })
    ARGV = ARGV[-1]
}

if (length(ARGV) > 0)
    db = ARGV[1]

if (is.null(db) || ! file.exists(db))
    stop("You must specify a valid, existing database")

library(RSQLite)
con = dbConnect(SQLite(), db)

dbtab = dbListTables(con)
if (length(tabpat) == 0) {
    ## drop those already ending in "_"
    tables = grep("_$", dbtab, perl=TRUE, value=TRUE, invert=TRUE)
} else {
    tables = unique(sapply(tabpat, function(x) grep(x, dbtab, perl=TRUE, val=TRUE)))
}


if (length(tables) == 0)
    stop("No tables to humanize")

for (t in tables) {
    dbcols = dbListFields(con, t)
    if (length(colpat) == 0) {
        colpat = "^ts([A-Z0-9].*)?$"
    }
    cols = unique(unlist(sapply(colpat, function(x) grep(x, dbcols, perl=TRUE, val=TRUE))))
    if (length(cols) > 0) {
        items = structure(as.list(dbcols), names=dbcols)
        for (col in cols) {
            items[col] = sprintf("strftime('%s',%s,'unixepoch') as %s", format, col, col)
        }
        vn = paste0(t, "_")
        DBI::dbExecute(con, paste0("drop view if exists ", vn))
        DBI::dbExecute(con, paste0("create view ", vn, " as select ", paste0(as.list(items), collapse=","), " from ", t))
        cat("Created view", vn, "as view of table", t, "with humanized timestamps\n")
    }
}
