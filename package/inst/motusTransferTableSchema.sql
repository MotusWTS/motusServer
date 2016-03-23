-- A batch is the result of processing one set of raw data files from
-- a single receiver.

CREATE TABLE IF NOT EXISTS batches (
    batchID INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT, -- unique identifier for this batch
    motusRecvID INTEGER NOT NULL,                        -- motus ID of receiver this batch of data came from
                                                         -- foreign key to Motus DB table.
    monoBN INT,                                          -- boot number for this receiver (NULL
                                                         -- okay, e.g. Lotek)
    tsBegin FLOAT(53) NOT NULL,                          -- timestamp for start of period
                                                         -- covered by batch
    tsEnd FLOAT(53) NOT NULL,                            -- timestamp for end of period
                                                         -- covered by batch
    numHits BIGINT NOT NULL,                             -- count of hits in this batch
    ts FLOAT(53) NOT NULL,                               -- timestamp this batch record added
    tsMotus FLOAT(53)                                    -- timestamp this record received by motus

);----  the four dashes after the semicolon delimits individual SQL statements for R code

-- GPS fixes are recorded separately from tag detections.

CREATE TABLE IF NOT EXISTS gps (
    ts      FLOAT(53) NOT NULL,                  -- receiver timestamp for this record
    batchID INTEGER NOT NULL REFERENCES batches, -- batch from which this fix came
    gpsts   FLOAT(53),                           -- gps timestamp
    lat     FLOAT(53),                           -- latitude, decimal degrees
    lon     FLOAT(53),                           -- longitude, decimal degrees
    alt     FLOAT(24),                           -- altitude, metres
    tsMotus FLOAT(53),                           -- timestamp this record received by motus
    PRIMARY KEY (batchID, ts)
);----


-- A run is a sequence of detections of a single tag by a single
-- antenna of a single receiver.  A run can start in one batch and
-- end in another, later batch.  The separation of detections into
-- batches does not affect the assignment of detections to runs.
-- Two fields in "runs" can need updating when subsequent batches
-- are processed: batchIDend, and len; 

CREATE TABLE IF NOT EXISTS runs (
    runID BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT, -- identifier of run; unique for this receiver
    batchIDbegin INTEGER NOT NULL REFERENCES batches, -- unique identifier of batch this run began in
    batchIDend INTEGER REFERENCES batches,            -- unique identifier of batch this run ends in, if the
                                                      -- run has ended.  Otherwise, this field is null, and
                                                      -- the value of len, below, is the number of hits *so far*
    motusTagID INT NOT NULL,                          -- ID for the tag detected; foreign key to Motus DB
                                                      -- table; a negative value correspond to an entry in the batchAmbig table.
    ant TINYINT NOT NULL,                             -- antenna number (USB Hub port # for SG; antenna port
                                                      -- # for Lotek)
    len BIGINT NOT NULL,                              -- number of detections in run ( so far ); this number
                                                      -- can increase 
    tsMotus FLOAT(53)                                 -- timestamp this record received by motus;
);----


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
    tsMotus FLOAT(53),                        -- timestamp this record received by motus
    PRIMARY KEY (runID, batchID)              -- only one update per run per batch
);----


-- Hits are detections of tags.  They are grouped in two ways:
-- by runs (consecutive detections of a single tag by a single antenna)
-- by batches (all detections of all tags from a set of raw input files)
-- Runs can span across batches.  

CREATE TABLE IF NOT EXISTS hits (
    hitID BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT, -- unique ID of this hit
    runID BIGINT NOT NULL REFERENCES runs,            -- ID of run this hit belongs to
    batchID INTEGER NOT NULL REFERENCES batches,      -- ID of batch this hit belongs to
    ts FLOAT(53) NOT NULL,                            -- timestamp (centre of first pulse in detection);
                                                      -- unix-style: seconds since 1 Jan 1970 GMT
    sig FLOAT(24) NOT NULL,                           -- signal strength, in units appropriate to device;
                                                      -- e.g.; for SG/funcube; dB (max); for Lotek: raw
                                                      -- integer in range 0..255
    sigSD FLOAT(24),                                  -- standard deviation of signal strength, in device
                                                      -- units (NULL okay; e.g. Lotek)
    noise FLOAT(24),                                  -- noise level, in device units (NULL okay; e.g. Lotek)
    freq FLOAT(24),                                   -- frequency offset, in kHz (NULL okay; e.g. Lotek)
    freqSD FLOAT(24),                                 -- standard deviation of freq, in kHz (NULL okay;
                                                      -- e.g. Lotek)
    slop FLOAT(24),                                   -- discrepancy of pulse timing, in msec (NULL okay;
                                                      -- e.g. Lotek)
    burstSlop FLOAT (24),                             -- discrepancy of burst timing, in msec (NULL okay;
                                                      -- e.g. Lotek)
    tsMotus FLOAT(53)                                 -- timestamp this record received by motus;
);----


-- Table batchAmbig records sets of physically identical tags which
-- have overlapping deployment periods.  When the motusTagID field in
-- a row of the 'runs' table is negative, its absolute value refers to
-- the ambigID field in this table.  The set of possible tags
-- corresponding to that detection is given by the motusTagID fields
-- of rows in this table which have the same ambigID.  Any of these
-- tags could, given the deployment dates, be the detected tag.
-- Users can try to resolve ambiguities using other context.

CREATE TABLE IF NOT EXISTS batchAmbig (
    ambigID INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT, -- identifier of group of tags which are ambiguous (identical)
    batchID INTEGER NOT NULL REFERENCES batches,         -- batch for which this ambiguity group is active
    motusTagID INT NOT NULL                              -- motus ID of tag in group.  
);----


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
    tsMotus FLOAT(53),                       -- timestamp this record received by motus;
    PRIMARY KEY (batchID, progName)          -- only one version of a given program per batch
);----


CREATE TABLE IF NOT EXISTS batchParams (
-- This table indicates what parameter values were used to run a btach.
-- Note that receiver version of this table store these values incrementally (noting
-- only the changes since the previous batch run), but that doesn't make sense
-- here since batches can have been run on different machines.

    batchID INT NOT NULL REFERENCES batches,   -- which batch run this parameter setting is for
    progName VARCHAR(16) NOT NULL,             -- identifier of program; e.g. 'find_tags',
                                               -- 'lotek-plugins.so'
    paramName VARCHAR(16) NOT NULL,            -- name of parameter (e.g. 'minFreq')
    paramVal FLOAT(53) NOT NULL,               -- value of parameter
    tsMotus FLOAT(53),                         -- timestamp this record received by motus;
    PRIMARY KEY (batchID, progName, paramName) -- only one value of a given parameter per program per batch
);----

-- Sometimes we will want to entirely replace a batch with 
-- a new one.  That is, any record with a foreign key 'batchID1'
-- will be deleted, then a bunch of new records will be inserted.
-- This table tracks such replacements

CREATE TABLE IF NOT EXISTS batchReplace (
    oldBatchID INT PRIMARY KEY UNIQUE NOT NULL REFERENCES batches, -- original batch ID
    newBatchID INT NOT NULL REFERENCES batches,                    -- new batch ID
    ts FLOAT(53) NOT NULL,                                         -- timestamp when this batch record was added;
    tsMotus FLOAT(53)                                              -- timestamp when this record transferred to motus;
);----
