#' make sure a receiver database has the required tables
#'
#' @param src dplyr sqlite src, as returned by \code{dplyr::src_sqlite()}
#' 
#' @return returns NULL (silently); fails on any error
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgEnsureDBTables = function(src) {
    if (! inherits(src, "src_sqlite"))
        stop("src is not a dplyr::src_sqlite object")
    con = src$con
    if (! inherits(con, "SQLiteConnection"))
        stop("src is not open or is corrupt; underlying db connection invalid")

    ## function to send a single statement to the underlying connection
    sql = function(...) dbGetQuery(con, sprintf(...))   

    tables = src_tbls(src)

    if (! "meta" %in% tables) {
        sql("
create table meta (  
key  character not null unique primary key, -- name of key for meta data
val  character                              -- character string giving meta data; might be in JSON format
)
");
        sql("create index meta_key on meta ( key )")
    }

    if (! "files" %in% tables) {
    sql("
create table files (  
fileID   integer not null primary key,             -- file ID - used in most data tables
name     text unique,                              -- name of file (basename only; no path, no compression extension)
size     integer,                                  -- size of uncompressed file contents
bootnum  integer,                                  -- boot number: number of times SG was booted before this file was recorded
monoBN   integer,                                  -- monotonic boot number: corrects issues with bn for BB white receivers, e.g.
ts       double,                                   -- timestamp from filename (time at which file was created)
tscode   character(1),                             -- timestamp code: 'P'=prior to GPS fix; 'Z' = after GPS fix
tsDB     double,                                   -- timestamp when file was read into this database
isDone   integer,                                   -- if non-zero, this was a complete, valid compressed file, so will never be updated.
contents BLOB                                      -- contents of file; bzip2-compressed text contents of file
)
");

    sql("create index files_name on files ( name )")
    sql("create index files_bootnum on files ( monoBN )")
    sql("create index files_ts on files ( ts )")
    sql("create index files_all on files ( monoBN, ts )")
  }

  ## a database of timepins mapping GPS timestamps to system timestamps, for periods when
  ## chrony has not updated the system clock (or when this fails entirely)
  ## this table should contain only one record per (depID, bootnum) pair
 
  if (! "timepins" %in% tables) {
    sql("
create table timepins (  
bootnum  integer,                                  -- boot number: number of times SG was booted before this file was recorded
systs    double,                                   -- system timestamp for GPS fix
gpsts    double                                    -- GPS timestamp from GPS fix
)");
  }

  ##  If this turns out to be an issue for more receivers than just the one on the Ryan Leet, implement this
  
  ## A table of points when the time unexplainedly jumps forward to a ridiculous value (years in the future)
  ## This has been on the unit deployed on the ship Ryan Leet, for example.
  ## It seems rare, but we don't assume it only happens once per boot, so we try to detect
  ## any time the system clock jumps forward more than 1 day within a single file

    if (! "timeJumps" %in% tables) {
        sql("
create   table timeJumps (  
bootnum  integer,                                  -- boot number: number of times SG was booted before this file was recorded
tsBefore double,                                   -- system timestamp before a big jump
tsAfter  double                                    -- system timestamp after a big jump
)");

    sql("create unique index timeJumps_all on timeJumps ( bootnum, tsBefore )")
  }

  if (! "gps" %in% tables) {
    sql("
create table gps (
ts      double unique primary key,           -- system timestamp for this record
gpsts   double,                              -- gps timestamp
lat     double,                              -- latitude, decimal degrees
lon     double,                              -- longitude, decimal degrees
alt     double                               -- altitude, metres
)");
    
    sql("create index gps_ts on gps ( ts )")
  }

  if (! "params" %in% tables) {
    sql( "
create table params (
ts      double,                              -- timestamp for this record
tscode  character(1),                        -- timestamp code: 'P'=prior to GPS fix; 'Z' = after GPS fix
port    integer,                             -- hub port -- for which device setting applies
param   text,                                -- parameter name
val     double,                              -- parameter setting
error   integer,                             -- 0 if parameter setting succeeded; error code otherwise
errinfo character                            -- non-empty if error code non-zero
)");

    sql("create index params_ts on params ( ts )")
    sql("create unique index params_all on params ( ts, port)")
  }

  if (! "pulseCounts" %in% tables) {
      sql("
create table pulseCounts (
pcode   character(2),                        -- code for pulse; typically p1, p2, p3, etc.
hourBin integer,                             -- hour bin for this count; this is round(ts/3600) for pulses from this file
count   integer,                             -- number of pulses for given pcode in this file
bootnum integer                              -- boot count for file generating this record
)");
      
      sql( "create index pulseCounts_hourBin on pulseCounts ( hourBin )")
      sql( "create index pulseCounts_pcode on pulseCounts ( pcode )")
      sql( "create index pulseCounts_all on pulseCounts ( hourBin, pcode )")
  }
}
