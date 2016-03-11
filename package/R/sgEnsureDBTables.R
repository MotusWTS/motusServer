#' make sure a receiver database has the required tables
#'
#' @param src dplyr sqlite src, as returned by \code{dplyr::src_sqlite()}
#' 
#' @return returns NULL (silently); fails on any error
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

## list of tables needed in the receiver database

sgTableNames = c("meta", "files", "timepins", "timeJumps", "GPS", "params", "pulseCounts", "batches",
                 "runs", "hits", "batchProgs", "batchParams", "batchState", "batchAmbig", "DTAfiles",
                 "DTAtags")

sgEnsureDBTables = function(src) {
    if (! inherits(src, "src_sqlite"))
        stop("src is not a dplyr::src_sqlite object")
    con = src$con
    if (! inherits(con, "SQLiteConnection"))
        stop("src is not open or is corrupt; underlying db connection invalid")

    tables = src_tbls(src)

    if (all(sgTableNames %in% tables))
        return()
    
    ## function to send a single statement to the underlying connection
    sql = function(...) dbGetQuery(con, sprintf(...))   

    if (! "meta" %in% tables) {
        sql("
create table meta (  
key  character not null unique primary key, -- name of key for meta data
val  character                              -- character string giving meta data; might be in JSON format
)
");
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

    if (! "DTAfiles" %in% tables) {
    sql("
create table DTAfiles (  
fileID   integer not null primary key,             -- file ID - used in most data tables
name     text,                                     -- name of file (no path, but extension preserved)
size     integer,                                  -- size of uncompressed file contents
tsBegin  double,                                   -- earliest timestamp in file
tsEnd    double,                                   -- latest timestamp in file
tsDB     double,                                   -- timestamp when file was read into this database
hash     text unique,                              -- because Lotek filenames are arbitrary and user-created,
                                                   -- we ensure uniqueness in the DB via SHA-512 hash of uncompressed contents
contents BLOB                                      -- contents of file; bzip2-compressed text contents of file
)
");

    sql("create index DTAfiles_hash on DTAfiles ( hash )")
    sql("create index DTAfiles_tsBegin on DTAfiles ( tsBegin )")
  }

    ## parsed contents of DTA files are stored in a separate table
    
    if (! "DTAtags" %in% tables) {
    sql("
create table DTAtags (
fileID   integer not null references DTAfiles,     -- ID of DTA file this record came from
dtaline  integer not null,                         -- index of line in .DTA file this detection is from (starting from 1)
ts       double,                                   -- timestamp of detection
id       integer,                                  -- Lotek tag ID (for given codeset)
ant      text,                                     -- code of antenna on which detected
sig      integer,                                  -- signal value
lat      double,                                   -- latitude of detection, in decimal degrees N (so -ve means S)
lon      double,                                   -- longitude of detection, in decimal degrees E (so -ve means W)
antFreq  double,                                   -- antenna frequency, in MHz
gain     int,                                      -- antenna gain in Lotek units
codeSet  text,                                     -- codeset of tag ('Lotek3' or 'Lotek4')
primary key(ts, ant, id)                          -- no more than one detection of each ID at given time, ant 
)
");

    sql("create index DTAtags_ts on DTAtags ( ts )")
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

    if (! "batches" %in% tables) {
        sql("
CREATE TABLE batches (
    ID INTEGER PRIMARY KEY,                   -- unique identifier for this batch
    monoBN INT,                               -- boot number for this receiver; (NULL
                                              -- okay; e.g. Lotek)
    tsBegin FLOAT(53),                        -- timestamp for start of period
                                              -- covered by batch; unix-style:
                                              -- seconds since 1 Jan 1970 GMT
    tsEnd FLOAT(53),                          -- timestamp for end of period
                                              -- covered by batch; unix-style:
                                              -- seconds since 1 Jan 1970 GMT
    numHits BIGINT,                           -- count of hits in this batch
    ts FLOAT(53)                              -- timestamp when this batch record was
                                              -- added; unix-style: seconds since 1
                                              -- Jan 1970 GMT
);
")
    }

    if (! "batchAmbig" %in% tables) {
        sql("
CREATE TABLE batchAmbig (
    ambigID INTEGER NOT NULL,                    -- identifier of group of tags which are ambiguous (identical); will be negative
    batchID INTEGER NOT NULL REFERENCES batches, -- batch for which this ambiguity group is active
    motusTagID INT NOT NULL                      -- motus ID of tag in group.  
);
")
        sql( "create index batchAmbig_motusTagID on batchAmbig(motusTagID)")
        sql( "create index batchAmbig_batchID on batchAmbig(batchID)")
    }


    if (! "runs" %in% tables) {
        sql("
CREATE TABLE runs (
    runID INTEGER PRIMARY KEY,                        -- identifier of run; unique for this receiver
    batchIDbegin INTEGER NOT NULL REFERENCES batches, -- unique identifier of batch this run began in
    batchIDend INTEGER NOT NULL REFERENCES batches,   -- unique identifier of batch this run began in
    motusTagID INT NOT NULL,                          -- ID for the tag detected; foreign key to Motus DB
                                                      -- table
    len INT,                                          -- length of run within batch
    tsMotus FLOAT(53)                                 -- timestamp when this record transferred to motus;
                                                      -- unix-style: seconds since 1 Jan 1970 GMT; NULL means
                                                      -- not transferred; if this timestamp is set, it means
                                                      -- all the hits for the run have also been transferred
);

")
    }
    if (! "hits" %in% tables) {
        sql("
CREATE TABLE hits (
    hitID INTEGER PRIMARY KEY,                     -- unique ID of this hit
    runID INTEGER NOT NULL REFERENCES runs,        -- ID of run this hit belongs to
    batchID INTEGER NOT NULL REFERENCES batches,   -- ID of batch this hit belongs to
    ant TINYINT NOT NULL,                          -- antenna number (USB Hub port # for SG; antenna port
                                                   -- # for Lotek)
    ts FLOAT(53) NOT NULL,                         -- timestamp (centre of first pulse in detection);
                                                   -- unix-style: seconds since 1 Jan 1970 GMT
    sig FLOAT(24) NOT NULL,                        -- signal strength, in units appropriate to device;
                                                   -- e.g.; for SG/funcube; dB (max); for Lotek: raw
                                                   -- integer in range 0..255
    sigSD FLOAT(24),                               -- standard deviation of signal strength, in device
                                                   -- units (NULL okay; e.g. Lotek)
    noise FLOAT(24),                               -- noise level, in device units (NULL okay; e.g. Lotek)
    freq FLOAT(24),                                -- frequency offset, in kHz (NULL okay; e.g. Lotek)
    freqSD FLOAT(24),                              -- standard deviation of freq, in kHz (NULL okay;
                                                   -- e.g. Lotek)
    slop FLOAT(24),                                -- discrepancy of pulse timing, in msec (NULL okay;
                                                   -- e.g. Lotek)
    burstSlop FLOAT (24)                           -- discrepancy of burst timing, in msec (NULL okay;
                                                   -- e.g. Lotek)
);
")
    }
    if (! "batchProgs" %in% tables) {
        sql("
-- This table only records changes to progVersion, or progBuildTS by batchID.
-- It is assumed batchIDs are chronological, and that any change applies to all
-- batches after a given record.
CREATE TABLE batchProgs (
    batchID INT NOT NULL references batches, -- which batch run this record refers to
    progName VARCHAR(16) NOT NULL,           -- identifier of program; e.g. 'find_tags',
                                             -- 'lotek-plugins.so'
    progVersion CHAR(40) NOT NULL,           -- git commit hash for version of code used
    progBuildTS FLOAT(53) NOT NULL,          -- timestamp of binary for this program; unix-style:
                                             -- seconds since 1 Jan 1970 GMT; NULL means not
                                             -- transferred
    tsMotus FLOAT(53),                       -- timestamp when this record transferred to motus;
                                             -- unix-style: seconds since 1 Jan 1970 GMT; NULL means
                                             -- not transferred
    PRIMARY KEY (batchID, progName)          -- only one version of a given program per batch
);
")
    }
    if (! "batchParams" %in% tables) {
        sql("
CREATE TABLE batchParams (
-- This table only records changes to parameters by batchID.
-- The value of a parameter used to run batch X is the value in this table from
-- the record with the largest batchID not exceeding X.
-- i.e. it is assumed batchIDs are chronological, and that any change applies to all
-- batches after a given record.
    batchID INT NOT NULL references batches,   -- which batch run this parameter setting is for
    progName VARCHAR(16) NOT NULL,             -- identifier of program; e.g. 'find_tags',
                                               -- 'lotek-plugins.so'
    paramName varchar(16) NOT NULL,            -- name of parameter (e.g. 'minFreq')
    paramVal FLOAT(53) NOT NULL,               -- value of parameter
    tsMotus FLOAT(53),                         -- timestamp when this record transferred to motus;
                                               -- unix-style: seconds since 1 Jan 1970 GMT; NULL means
                                               -- not transferred
    PRIMARY KEY (batchID, progName, paramName) -- only one value of a given parameter per program per batch
);
")
    }

    if (! "batchState" %in% tables) {
        sql("
CREATE TABLE batchState (
-- This table records the state of a program used when it last finished running; this
-- can be used to resume it when new data arrive.
    batchID INT NOT NULL references batches,      -- ID of batch which was being processed when program paused
    progName VARCHAR(16) NOT NULL,                -- identifier of program; e.g. 'find_tags',
                                                  -- 'lotek-plugins.so'
    monoBN INT NOT NULL,                          -- montonic boot count of last batch
    tsData FLOAT(53),                             -- timestamp (seconds since unix epoch) of last processed line in previous input
    tsRun FLOAT(53),                              -- timestamp (seconds since unix epoch) when program was paused
    lastFileID INTEGER NOT NULL references files, -- ID of last file processed
    lastCharIndex INTEGER NOT NULL,               -- offset in (uncompressed file) of last char processed
    state  BLOB,                                  -- serialized state of program, if needed

    PRIMARY KEY (batchID, progName)               -- only one saved state per program per batch
);
")
    }

}
