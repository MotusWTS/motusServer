-- This is the schema for the tables used to transfer output from the tagfinder to motus.
--
-- NOTE: individual SQL statements in this file are delimited by ';----', so that R code
-- can submit each statement to dbGetQuery() individually (dbGetQuery doesn't support
-- compound statements)

-----------------------------------------------------------------------------------------

-- A batch is the result of processing one set of raw data files from
-- a single receiver.  Batches are an artefact of how data is
-- received, and distribution of files among batches should not affect
-- the final output.

CREATE DATABASE motus;
USE motus;

CREATE TABLE IF NOT EXISTS batches (
    batchID INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT, -- unique identifier for this batch
    motusDeviceID INTEGER NOT NULL,                      -- motus ID of device this batch of data came from
                                                         -- foreign key to Motus DB table.
    monoBN INT,                                          -- boot number for this receiver (NULL
                                                         -- okay, e.g. Lotek)
    tsBegin FLOAT(53) NOT NULL,                          -- timestamp for start of period
                                                         -- covered by batch
    tsEnd FLOAT(53) NOT NULL,                            -- timestamp for end of period
                                                         -- covered by batch
    numHits BIGINT NOT NULL,                             -- count of hits in this batch
    ts FLOAT(53) NOT NULL,                               -- timestamp this batch record added
    tsMotus FLOAT(53) NOT NULL DEFAULT -1                -- timestamp this record received by motus

);----

CREATE INDEX batches_tsMotus on batches(tsMotus);----

-- GPS fixes are recorded separately from tag detections.

CREATE TABLE IF NOT EXISTS gps (
    ts      FLOAT(53) NOT NULL,                  -- receiver timestamp for this record
    batchID INTEGER NOT NULL REFERENCES batches, -- batch from which this fix came
    gpsts   FLOAT(53),                           -- gps timestamp
    lat     FLOAT(53),                           -- latitude, decimal degrees
    lon     FLOAT(53),                           -- longitude, decimal degrees
    alt     FLOAT(24),                           -- altitude, metres
    PRIMARY KEY (batchID, ts)
);----


-- A run is a sequence of detections of a single tag by a single
-- antenna of a single receiver.  A run can start in one batch and
-- end in another, later batch.  The separation of detections into
-- batches does not affect the assignment of detections to runs.
-- Two fields in "runs" can need updating when subsequent batches
-- are processed: batchIDend, and len

CREATE TABLE IF NOT EXISTS runs (
    runID BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT, -- identifier of run; unique for this receiver
    batchIDbegin INTEGER NOT NULL REFERENCES batches, -- unique identifier of batch this run began in
    batchIDend INTEGER REFERENCES batches,            -- unique identifier of batch this run ends in, if the
                                                      -- run has ended.  Otherwise, this field is null, and
                                                      -- the value of len, below, is the number of hits *so far*
    motusTagID INT NOT NULL,                          -- ID for the tag detected; foreign key to Motus DB
                                                      -- table; a negative value correspond to an entry in the tagAmbig table.
    ant TINYINT NOT NULL,                             -- antenna number (USB Hub port # for SG; antenna port
                                                      -- # for Lotek)
    len BIGINT NOT NULL                               -- number of detections in run ( so far ); this number
                                                      -- can increase
);----

CREATE INDEX runs_motusTagID ON runs(motusTagID);----
CREATE INDEX runs_batchIDbegin ON runs(batchIDbegin);----

-- Because runs can span multiple batches, we need a way to
-- update some of their fields:
--    len: each new batch in which the run is still active
--         will add its detections of to this field
--    batchIDend: when a run has finally ended in a batch,
--         this field will be updated with a non-null batchID
--
-- Records in the runUpdates table refer to runs begun in
-- previous batches, and indicate how to update their fields.

CREATE TABLE IF NOT EXISTS runUpdates (
    runID BIGINT NOT NULL REFERENCES runs,    -- identifier of run for which this record is an update
    batchID INT NOT NULL REFERENCES batches,  -- batch from which this run update record came
    len BIGINT NOT NULL,                      -- replacement length for this run
    batchIDend INT REFERENCES batches,        -- replacement batchIDend for this run (if not null)
    PRIMARY KEY (runID, batchID)              -- only one update per run per batch
);----

CREATE INDEX runUpdates_runID ON runUpdates(runID);----
CREATE INDEX runUpdates_batchID ON runUpdates(batchID);----

-- Hits are detections of tags.  They are grouped in two ways:
-- by runs (consecutive detections of a single tag by a single antenna)
-- by batches (all detections of all tags from a set of raw input files)
-- Runs can span across batches.

CREATE TABLE IF NOT EXISTS hits (
    hitID BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT, -- unique ID of this hit
    runID BIGINT NOT NULL REFERENCES runs,            -- ID of run this hit belongs to
    batchID INTEGER NOT NULL REFERENCES batches,      -- ID of batch this hit belongs to
    ts FLOAT(53) NOT NULL,                            -- timestamp (centre of first pulse in detection)
                                                      -- unix-style: seconds since 1 Jan 1970 GMT
    sig FLOAT(24) NOT NULL,                           -- signal strength, in units appropriate to device
                                                      -- e.g.; for SG/funcube; dB (max); for Lotek: raw
                                                      -- integer in range 0..255
    sigSD FLOAT(24),                                  -- standard deviation of signal strength, in device
                                                      -- units (NULL okay; e.g. Lotek)
    noise FLOAT(24),                                  -- noise level, in device units (NULL okay; e.g. Lotek)
    freq FLOAT(24),                                   -- frequency offset, in kHz (NULL okay; e.g. Lotek)
    freqSD FLOAT(24),                                 -- standard deviation of freq, in kHz (NULL okay
                                                      -- e.g. Lotek)
    slop FLOAT(24),                                   -- discrepancy of pulse timing, in msec (NULL okay
                                                      -- e.g. Lotek)
    burstSlop FLOAT (24)                              -- discrepancy of burst timing, in msec (NULL okay
                                                      -- e.g. Lotek)
);----

CREATE INDEX hits_batchID ON hits(batchID);----
CREATE INDEX hits_runID ON hits(runID);----

-- Table tagAmbig records sets of physically identical tags which have
-- overlapping deployment periods.  When the motusTagID field in a row
-- of the 'runs' table is negative, it refers to the ambigID field in
-- this table.  The set of possible tags corresponding to that
-- detection is given by the motusTagIDX fields of the corresponding
-- row in this table joined like so:
--
-- Any of these tags could, given the deployment dates, be the
-- detected tag.  Users can try to resolve ambiguities using other
-- context.

CREATE TABLE IF NOT EXISTS tagAmbig (
    ambigID INTEGER PRIMARY KEY NOT NULL,  -- identifier of group of tags which are ambiguous (identical); will be negative
    motusTagID1 INT NOT NULL,              -- motus ID of tag in group (not null because there have to be at least 2)
    motusTagID2 INT NOT NULL,              -- motus ID of tag in group.(not null because there have to be at least 2)
    motusTagID3 INT,                       -- motus ID of tag in group.
    motusTagID4 INT,                       -- motus ID of tag in group.
    motusTagID5 INT,                       -- motus ID of tag in group.
    motusTagID6 INT,                       -- motus ID of tag in group.
    tsMotus FLOAT(53) NOT NULL DEFAULT -1  -- timestamp this record received by motus
);----

CREATE UNIQUE INDEX tagAmbig_motusTagID ON tagAmbig(motusTagID1, motusTagID2, motusTagID3, motusTagID4, motusTagID5, motusTagID6);----
CREATE INDEX tagAmbig_tsMotus ON tagAmbig(tsMotus);----

-- Table batchProgs records values of progVersion and progBuildTS by batchID.
-- Note that receiver version of this table store these values incrementally (noting
-- only the changes since the previous batch run), but that doesn't make sense
-- here since batches can have been run on different machines.

CREATE TABLE IF NOT EXISTS batchProgs (
    batchID INT NOT NULL REFERENCES batches, -- which batch run this record refers to
    progName VARCHAR(16) NOT NULL,           -- identifier of program; e.g. 'find_tags',
                                             -- 'lotek-plugins.so'
    progVersion CHAR(40) NOT NULL,           -- git commit hash for version of code used
    progBuildTS FLOAT(53) NOT NULL,          -- timestamp of binary for this program; unix-style:
                                             -- seconds since 1 Jan 1970 GMT; NULL means not
                                             -- transferred
    PRIMARY KEY (batchID, progName)          -- only one version of a given program per batch
);----

CREATE INDEX batchProgs_batchID ON batchProgs(batchID);----

CREATE TABLE IF NOT EXISTS batchParams (
-- This table indicates what parameter values were used to run a btach.
-- Note that receiver version of this table store these values incrementally (noting
-- only the changes since the previous batch run), but that doesn't make sense
-- here since batches can have been run on different machines.

    batchID INT NOT NULL REFERENCES batches,   -- which batch run this parameter setting is for
    progName VARCHAR(16) NOT NULL,             -- identifier of program; e.g. 'find_tags',
                                               -- 'lotek-plugins.so'
    paramName VARCHAR(32) NOT NULL,            -- name of parameter (e.g. 'minFreq')
    paramVal FLOAT(53) NOT NULL,               -- value of parameter
    PRIMARY KEY (batchID, progName, paramName) -- only one value of a given parameter per program per batch
);----

CREATE INDEX batchParams_batchID ON batchParams(batchID);----

CREATE TABLE IF NOT EXISTS pulseCounts (
-- This table records antenna activity.  Neither Lotek nor SG
-- receivers provide explicit reports of antenna status, so we just
-- record the approximate number of pulses detected per hour on each
-- antenna.  A non-zero value is treated as "antenna was working".
-- These pulses are from both valid tag detections and noise or id =
-- 999 detections (the latter treated as only a single pulse).

    batchID INT NOT NULL REFERENCES batches, -- which batch run these pulse counts are for
    ant TINYINT NOT NULL,                    -- antenna
    hourBin INT,                             -- hour bin for this count; this is round(ts/3600)
    count   INT,                             -- number of pulses for given pcode in this file
    PRIMARY KEY (batchID, ant, hourBin)      -- a single count for each batchID, antenna, and hourBin
);----

CREATE INDEX pulseCounts_batchID ON pulseCounts(batchID);----

-- Sometimes we will want to entirely replace a bunch of batches with
-- new ones.  Really, we just delete the old batches, and insert
-- new ones (or not).  This table records deletions.  We will guarantee
-- that no runs cross in or out of the range of batches specified by a single
-- record of this table.  i.e. for any run, all of its hits are from batches
-- in the range batchIDbegin...batchIDend, or all of its hits are from batches
-- before batchIDbegin, or all of its hits are from batches after batchIDend.

CREATE TABLE IF NOT EXISTS batchDelete (
    batchIDbegin INT PRIMARY KEY UNIQUE NOT NULL REFERENCES batches,-- first batch to be deleted
    batchIDend INT NOT NULL REFERENCES batches,                     -- last batch to be deleted
    ts FLOAT(53) NOT NULL,                                          -- timestamp when this batch deletion record was added
    reason TEXT,                                                    -- human-readable explanation for why a batch was deleted
    tsMotus FLOAT(53) NOT NULL DEFAULT -1                           -- timestamp when this record transferred to motus
);----

CREATE INDEX batchDelete_batchIDend ON batchDelete(batchIDend);----

CREATE TABLE IF NOT EXISTS sg_import_log (
    batchID INT PRIMARY KEY UNIQUE NOT NULL REFERENCES batches,
    transfer_dt FLOAT(53) NOT NULL,
    success INT,
    msg TEXT
);----

-- grant privileges to remote user 'denis' to pull data and update the sg_import_log table
-- pulled data are indicated by setting the tsMotus field in appropriate tables.

GRANT SELECT, UPDATE(tsMotus)   ON motus.batchDelete    TO 'denis'@'%';
GRANT SELECT                    ON motus.batchParams    TO 'denis'@'%';
GRANT SELECT                    ON motus.pulseCounts    TO 'denis'@'%';
GRANT SELECT                    ON motus.batchProgs     TO 'denis'@'%';
GRANT SELECT, UPDATE (tsMotus)  ON motus.batches        TO 'denis'@'%';
GRANT SELECT                    ON motus.gps            TO 'denis'@'%';
GRANT SELECT                    ON motus.hits           TO 'denis'@'%';
GRANT SELECT                    ON motus.runUpdates     TO 'denis'@'%';
GRANT SELECT                    ON motus.runs           TO 'denis'@'%';
GRANT SELECT, UPDATE            ON motus.sg_import_log  TO 'denis'@'%';
GRANT SELECT, UPDATE (tsMotus)  ON motus.tagAmbig       TO 'denis'@'%';

-- Table upload_tokens records tokens granted to users for data transfers

CREATE TABLE IF NOT EXISTS upload_tokens (
       token CHAR(32) PRIMARY KEY UNIQUE NOT NULL, -- token; looks like "lofHipkeXXX" where XXX is 24 random alphanum chars
       username CHAR(64),                          -- name of user on sensorgnome.org
       email CHAR(128),                            -- email address of user on sensorgnome.org
       expiry FLOAT(53)                            -- unix timestamp when this token expires
);----
