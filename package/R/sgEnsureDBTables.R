#' make sure a receiver database has the required tables; also, load
#' custom SQLite extensions on this DB connection.
#'
#' @param src dplyr sqlite src, as returned by \code{dplyr::src_sqlite()}
#'
#' @param recreate vector of table names which should be dropped then re-created,
#' losing any existing data.  Defaults to empty vector, meaning no tables
#' are recreate.  As a special case, TRUE causes all tables to be dropped
#' then recreated.
#' 
#' @return returns NULL (silently); fails on any error
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgEnsureDBTables = function(src, recreate=c()) {
    if (! inherits(src, "src_sqlite"))
        stop("src is not a dplyr::src_sqlite object")
    con = src$con
    if (! inherits(con, "SQLiteConnection"))
        stop("src is not open or is corrupt; underlying db connection invalid")

    ## function to send a single statement to the underlying connection
    sql = function(...) dbGetQuery(con, sprintf(...))   

    sql("pragma page_size=4096") ## reasonably large page size; post 2011 hard drives have 4K sectors anyway
    
    if (isTRUE(recreate))
        recreate = sgTableNames
    
    ## load custom extensions
    sql("select load_extension('%s')",  system.file(paste0("libs/Sqlite_Compression_Extension", .Platform$dynlib.ext),package="motus"))
    
    for (t in recreate)
        sql("drop table %s", t)
    
    tables = src_tbls(src)

    if (all(sgTableNames %in% tables))
        return()
    
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


    ## A table of corrections applied to timestamps, e.g. for periods
    ## when chrony has not updated the SG system clock from the GPS (or
    ## for when this fails entirely).  Each record indicates a block
    ## of corrected times during a particular boot session, the amount
    ## by which they were corrected, and a code for the reason.
    ## When the tag finder is run, these corrections are applied to the
    ## ts field in the hits table, as well as to the tsBegin and tsEnd
    ## fields of the batches table.
    
    if (! "timeFixes" %in% tables) {
        sql("
create table timeFixes (  
batchID  integer,      -- batch ID during which fixes were made
tsFixedLow double,     -- low endpoint of timestamps after correction
tsFixedHigh double,    -- high endpoint of timestamps after correction
tsFixedBy double,      -- amount which was added to uncorrected timestamps to obtain corrected ones, in seconds.
comment text           -- method and reason for fixing; e.g. 'GPS pin'
)");
    }

    
    ## This table provides the information used to generate records in
    ## the timeFixes table, at least for the case where the timeFix is
    ## due to a delayed settting of the SG system clock from the GPS.
    ## This table is populated by the tag finder, which looks for
    ## instances of raw data timestamps jumping from invalid (before
    ## 2010) to valid (after 2010).  The difference will be used to
    ## back-correct the invalid timestamps on any detections before
    ## the setting.  The tag finder might also search for jumps
    ## due to wonky GPS data; e.g. significant time reversals, or
    ## jumps by a year etc.

    ## drop the old, unused version of timeJumps, if it exists
    if ("timeJumps" %in% tables &&
        identical(tbl_vars(tbl(src, "timeJumps")), c("bootnum", "tsBefore", "tsAfter")
                  )) {
        sql("drop table timeJumps")
        tables = tables[ - match("timeJumps", tables)]
    }
    
    if (! "timeJumps" %in% tables) {
        sql("
create table timeJumps (  
batchID  integer not null references batches,      -- batch ID from which this time setting record comes
tsBefore double not null,                          -- latest available timestamp before GPS set the system clock
tsAfter double not null,                           -- earliest available timestamp after GPS set the system clock
jumpType char(1)                                   -- a code providing the type of jump recorded here; 'S' means
                                                   -- 'setting', which is a jump from invalid to valid timestamps.
)");
    }

    if (! "gps" %in% tables) {
        sql("
create table gps (
ts      double unique primary key,           -- system timestamp for this record
batchID INTEGER NOT NULL REFERENCES batches, -- batch from which this fix came
gpsts   double,                              -- gps timestamp
lat     double,                              -- latitude, decimal degrees
lon     double,                              -- longitude, decimal degrees
alt     double                               -- altitude, metres
)");

        sql("create index gps_batchID on gps ( batchID )")

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
batchID integer NOT NULL REFERENCES batches, -- batchID that generated this record
ant TINYINT NOT NULL,                        -- antenna
hourBin integer,                             -- hour bin for this count; this is round(ts/3600)
count   integer,                             -- number of pulses for given pcode in this file
PRIMARY KEY (batchID, ant, hourBin)          -- a single count for each batchID, antenna, and hourBin
)");
    }

    if (! "batches" %in% tables) {
        sql("
CREATE TABLE batches (
    batchID INTEGER PRIMARY KEY,              -- unique identifier for this batch
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
    batchIDend INTEGER  REFERENCES batches,           -- unique identifier of batch this run ends in (if run is complete)
    motusTagID INT NOT NULL,                          -- ID for the tag detected; foreign key to Motus DB
                                                      -- table
    ant TINYINT NOT NULL,                             -- antenna number (USB Hub port # for SG; antenna port
                                                      -- # for Lotek)
    len INT                                           -- length of run within batch
);

")
    }
    if (! "hits" %in% tables) {
        sql("
CREATE TABLE hits (
    hitID INTEGER PRIMARY KEY,                     -- unique ID of this hit
    runID INTEGER NOT NULL REFERENCES runs,        -- ID of run this hit belongs to
    batchID INTEGER NOT NULL REFERENCES batches,   -- ID of batch this hit belongs to
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
        sql("CREATE INDEX IF NOT EXISTS hits_batchID_ts on hits(batchID, ts)")
        
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

    if (! "motusTX" %in% tables) {
        sql("
CREATE TABLE motusTX (
-- This table records the state of data transfers to motus, possibly via
-- transfer tables on discovery.acadiau.ca
-- Transfers occur in batch;
-- for one batchID, the records from these tables are transferred:
--  - batches
--  - runs (matching batchIDbegin)
--  - hits
--  - gps
--  - batchAmbig
--  - batchProg
--  - batchParam
--  - batchState
--
-- Any entries in runs which have batchIDbegin < batchIDend and for which
-- batchIDend is the current batchID also generate entries in runUpdates,
-- to close runs which have ended.
--
-- Many key fields must be mapped to new ones in pushing data to motus,
-- since data from different receivers will collide.  So when pushing data,
-- we request blocks of consecutive new keys in each destination table,
-- so that the map between receiver keys and motus keys is a simple offset.
-- (motusKey = receiverKey + OFFSET), where OFFSET will be a different value
-- for each table.  These OFFSETS are stored to permit mapping back from
-- motus key values to receiver tables.

-- can be used to resume it when new data arrive.
    batchID INT NOT NULL PRIMARY KEY references batches, -- ID of batch which was transferred
    tsMotus FLOAT(53),                                   -- timestamp when batch transferred
    offsetBatchID BIGINT,                                -- value added to receiver batchID field to get motus batchID field
    offsetRunID BIGINT,                                  -- value added to receiver runID field to get motus runID field for runs starting in this batch
    offsetHitID BIGINT                                   -- value added to receiver hitID field to get motus hitID field for hits in this batch
);
")
    }

}

## list of tables needed in the receiver database

sgTableNames = c("meta", "files", "timeFixes", "timeJumps", "GPS", "params", "pulseCounts", "batches",
                 "runs", "hits", "batchProgs", "batchParams", "batchState", "batchAmbig", "DTAfiles",
                 "DTAtags", "motusTX")
