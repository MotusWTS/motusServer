-- This is the schema for the tables used to transfer output from the tagfinder to motus.
--
-- NOTE: individual SQL statements in this file are delimited by a
-- semicolon then two dashes, so that R code can submit each statement
-- to dbGetQuery() individually (dbGetQuery doesn't support compound
-- statements)

-- ---------------------------------------------------------------------------------------

-- A batch is the result of processing one set of raw data files from
-- a single receiver.  Batches are an artefact of how data is
-- received, and distribution of files among batches should not affect
-- the final output.

-- CREATE DATABASE motus;
-- USE motus;

CREATE TABLE IF NOT EXISTS batches (
    batchID INTEGER NOT NULL PRIMARY KEY,                -- unique identifier for this batch
    motusDeviceID INTEGER NOT NULL,                      -- motus ID of device this batch of data came from
                                                         -- foreign key to Motus DB table.
    monoBN INT,                                          -- boot number for this receiver (NULL
                                                         -- okay, e.g. Lotek)
    tsStart FLOAT(53) NOT NULL,                          -- timestamp for start of period
                                                         -- covered by batch
    tsEnd FLOAT(53) NOT NULL,                            -- timestamp for end of period
                                                         -- covered by batch
    numHits BIGINT NOT NULL,                             -- count of hits in this batch
    ts FLOAT(53) NOT NULL,                               -- timestamp this batch record added
    tsMotus FLOAT(53) NOT NULL DEFAULT -1,               -- timestamp this record received by motus
    motusUserID INT,                                     -- user who uploaded the data leading to this batch
    motusProjectID INT,                                  -- user-selected motus project ID for this batch
    motusJobID INT,                                      -- processing job which created this batch
    recvDepProjectID INT                                 -- projectID of the receiver deployment this batch belongs to (NULL if not known).
                                                         -- this field allows much simpler queries for fetching data

);--

CREATE INDEX IF NOT EXISTS batches_tsMotus on batches(tsMotus);--
CREATE INDEX IF NOT EXISTS batches_recvDepProjectID ON batches(recvDepProjectID);--

-- A table to speed queries about which new batches are relevant to a given project.
-- This table has a record for each pair (projectID, batchID) where the latter has
-- a detection of a tag from the former.

CREATE TABLE IF NOT EXISTS projBatch (
       tagDepProjectID SMALLINT NOT NULL,
       batchID INTEGER NOT NULL,
       PRIMARY KEY(tagDepProjectID, batchID)
);--

-- GPS fixes are recorded separately from tag detections.

CREATE TABLE IF NOT EXISTS gps (
    ts      FLOAT(53) NOT NULL,                  -- receiver timestamp for this record
    batchID INTEGER NOT NULL REFERENCES batches, -- batch from which this fix came
    gpsts   FLOAT(53),                           -- gps timestamp
    lat     FLOAT(53),                           -- latitude, decimal degrees
    lon     FLOAT(53),                           -- longitude, decimal degrees
    alt     FLOAT(24),                           -- altitude, metres
    PRIMARY KEY (batchID, ts)
);--

-- A run is a sequence of detections of a single tag by a single
-- antenna of a single receiver.  A run can start in one batch and
-- end in another, later batch.  The separation of detections into
-- batches does not affect the assignment of detections to runs.
-- Two fields in "runs" can need updating when subsequent batches
-- are processed: batchIDend, and len

CREATE TABLE IF NOT EXISTS runs (
    runID BIGINT NOT NULL PRIMARY KEY,                -- identifier of run; unique for this receiver
    batchIDbegin INT NOT NULL,                        -- ID of batch this run begins in
    tsBegin FLOAT(53) NOT NULL,                       -- timestamp of first detection in the run
    tsEnd FLOAT(53) NOT NULL,                         -- timestamp of last detection in run so far (last pulse in completed burst, actually)
    done TINYINT NOT NULL DEFAULT 0,                  -- is run finished? 0 if no, 1 if yes.
    motusTagID INT NOT NULL,                          -- ID for the tag detected; foreign key to Motus DB
                                                      -- table; a negative value correspond to an entry in the tagAmbig table.
    ant TINYINT NOT NULL,                             -- antenna number (USB Hub port # for SG; antenna port
                                                      -- # for Lotek)
    len BIGINT NOT NULL,                              -- number of detections in run ( so far ); this number
                                                      -- can increase
    tagDepProjectID INT                               -- projectID of tag deployment the hits in this run belong to (NULL if not known).
                                                      -- this field allows much simpler queries for fetching data
);--

CREATE INDEX IF NOT EXISTS runs_motusTagID ON runs(motusTagID);--
CREATE INDEX IF NOT EXISTS runs_batchIDbegin ON runs(batchIDbegin);--
CREATE INDEX IF NOT EXISTS runs_tagDepProjectID ON runs(tagDepProjectID);--

-- Because runs can span multiple batches, we want a way to
-- keep track of which runs overlap which batches.
-- The batchRuns table is a many-to-many relation between
-- batchIDs and runIDs.

CREATE TABLE IF NOT EXISTS batchRuns (
    batchID INT NOT NULL REFERENCES batches,  -- batch ID
    runID BIGINT NOT NULL REFERENCES runs,    -- run ID
    tagDepProjectID SMALLINT,                 -- projectID that deployed tag for this run;
                                              -- (redundant since runs table has same info, but
                                              -- greatly speeds up queries used by `dataServer`
    PRIMARY KEY (batchID, runID)              -- only one update per run per batch
);--

CREATE INDEX IF NOT EXISTS batchRuns_batchID ON batchRuns(batchID);--
CREATE INDEX IF NOT EXISTS batchRuns_runID ON batchRuns(runID);--
CREATE INDEX IF NOT EXISTS batchRuns_tagDepProjectID_batchID_runID on batchRuns(tagDepProjectID, batchID, runID);--

-- Hits are detections of tags.  They are grouped in two ways:
-- by runs (consecutive detections of a single tag by a single antenna)
-- by batches (all detections of all tags from a set of raw input files)
-- Runs can span across batches.

CREATE TABLE IF NOT EXISTS hits (
    hitID BIGINT NOT NULL PRIMARY KEY,                -- unique ID of this hit
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
    burstSlop FLOAT (24),                             -- discrepancy of burst timing, in msec (NULL okay
                                                      -- e.g. Lotek)
    tagDepProjectID SMALLINT                          -- projectID that deployed tag this is a hit for
                                                      -- (redundant; same info is in matching record in runs
                                                      -- table, but allows for much faster queries by `dataServer`
);--

CREATE INDEX IF NOT EXISTS hits_batchID ON hits(batchID);--
CREATE INDEX IF NOT EXISTS hits_runID ON hits(runID);--
CREATE INDEX IF NOT EXISTS hits_ts on hits(ts);--
CREATE INDEX IF NOT EXISTS hits_tagDepProjectID_batchID_hitID ON hits(tagDepProjectID, batchID, hitID);

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
    ambigProjectID INT REFERENCES projAmbig, -- identifier of set of projects that could own this ambiguous tag
    tsMotus FLOAT(53) NOT NULL DEFAULT -1  -- timestamp this record received by motus
);--

CREATE UNIQUE INDEX IF NOT EXISTS tagAmbig_motusTagID ON tagAmbig(motusTagID1, motusTagID2, motusTagID3, motusTagID4, motusTagID5, motusTagID6);--
CREATE INDEX IF NOT EXISTS tagAmbig_tsMotus ON tagAmbig(tsMotus);--

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
);--

CREATE INDEX IF NOT EXISTS batchProgs_batchID ON batchProgs(batchID);--

CREATE TABLE IF NOT EXISTS batchParams (
-- This table indicates what parameter values were used to run a btach.
-- Note that receiver version of this table store these values incrementally (noting
-- only the changes since the previous batch run), but that doesn't make sense
-- here since batches can have been run on different machines.

    batchID INT NOT NULL REFERENCES batches,   -- which batch run this parameter setting is for
    progName VARCHAR(16) NOT NULL,             -- identifier of program; e.g. 'find_tags',
                                               -- 'lotek-plugins.so'
    paramName VARCHAR(32) NOT NULL,            -- name of parameter (e.g. 'minFreq')
    paramVal TEXT(53) NOT NULL,                -- value of parameter as a string
    PRIMARY KEY (batchID, progName, paramName) -- only one value of a given parameter per program per batch
);--

CREATE INDEX IF NOT EXISTS batchParams_batchID ON batchParams(batchID);--

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
);--

CREATE INDEX IF NOT EXISTS pulseCounts_batchID ON pulseCounts(batchID);--

CREATE TABLE IF NOT EXISTS tagDeployments (
       projectID INT NOT NULL,     -- motus project ID
       motusTagID INT NOT NULL,    -- motus tag ID
       tsStart FLOAT(53) NOT NULL, -- unix timestamp of start of deployment
       tsEnd FLOAT(53) NOT NULL,   -- unix timestamp of end of deployment
       INDEX tagDeployments_projectID (projectID),
       INDEX tagDeployments_motusTagID (motusTagID)
);--

CREATE TABLE IF NOT EXISTS receiverDeployments (
       projectID INT NOT NULL,     -- motus project ID
       deviceID INT NOT NULL,      -- motus device ID
       tsStart FLOAT(53) NOT NULL, -- unix timestamp of start of deployment
       tsEnd FLOAT(53) NOT NULL,   -- unix timestamp of end of deployment
       INDEX receiverDeployments_projectID (projectID),
       INDEX receiverDeployments_deviceID (deviceID)
);--

CREATE TABLE IF NOT EXISTS maxKeys (
-- This table records the maximum magnitude of the key value in one of the
-- tables where clients reserve blocks of keys:
-- batches, runs, hits, tagAmbig.
-- This allows an appropriate query to atomically reserve a block of
-- keys for a table, before writing data to it.
       tableName CHAR(32) PRIMARY KEY,  -- table name in this DB
       maxKey BIGINT                    -- maximum magnitude of "allocated" (reserved or actually used) key in this table
);--

CREATE TABLE IF NOT EXISTS batchProgs (
    batchID INT NOT NULL references batches, -- which batch run this record refers to
    progName VARCHAR(16) NOT NULL,           -- identifier of program; e.g. 'find_tags',
                                             -- 'lotek-plugins.so'
    progVersion CHAR(40) NOT NULL,           -- git commit hash for version of code used
    progBuildTS FLOAT(53) NOT NULL,          -- timestamp of binary for this program; unix-style:
                                             -- seconds since 1 Jan 1970 GMT; NULL means not
                                             -- transferred
    PRIMARY KEY (batchID, progName)          -- only one version of a given program per batch
);--

CREATE TABLE IF NOT EXISTS batchParams (
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
);--

-- Table projAmbig records sets of real projects that share an identical
-- tag with overlapping deployment periods.  When the tagDepProjectID field in a row
-- of the 'runs' or 'hits' table is negative, it refers to the ambigProjectID field in
-- this table.  The set of possible projects whose tag might have been detected
-- is given by the projectIDX fields of the corresponding row in this table joined like so.
--
-- e.g. the record (-10, 11, 17, null, null, null, null)
-- means that if a detection has tagDepProjectID = -10, the detection might be of
-- a tag in project 11, or of a tag in project 17.
-- (the motusTagID in this case will also be negative, and a corresponding row in the
-- tagAmbig table will list which real tags the detection could be).
-- Depending on which real tag was detected, any of these projects could be the owner
-- of that detection (i.e. Any of these tags could, given the deployment dates, be the
-- detected tag.  Users can try to resolve ambiguities using other
-- context.

CREATE TABLE IF NOT EXISTS projAmbig (
    ambigProjectID INTEGER PRIMARY KEY NOT NULL,  -- identifies a set of projects which a tag detection *could* belong to; negative
    projectID1 INT NOT NULL,              -- projectID of project in set
    projectID2 INT,                       -- projectID of project in set
    projectID3 INT,                       -- projectID of project in set
    projectID4 INT,                       -- projectID of project in set
    projectID5 INT,                       -- projectID of project in set
    projectID6 INT,                       -- projectID of project in set
    tsMotus FLOAT(53) NOT NULL DEFAULT -1  -- timestamp this record received by motus
);--
