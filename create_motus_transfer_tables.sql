--  TABLE hits 
-- 
--  each record is a detection of a tag embedded in a run of such detections; runs track detections
--  of a tag by a single antenna on a single receiver.  Note: time-varying metadata about the
--  receiver (e.g. location) or radios (e.g. listening frequency, gain) are transferred separately
--  in the tables "gps" and "params"

CREATE TABLE hits (
    batchID INT NOT NULL REFERENCES batches, -- ID of batch this hit belongs to
    ID INT NOT NULL,                         -- unique ID for this hit within this batch
    motusTagID INT NOT NULL,                 -- ID for the tag detected; foreign key to Motus DB table
    ant TINYINT NOT NULL,                    -- antenna number (USB Hub port # for SG; antenna port # for Lotek)
    ts FLOAT(53) NOT NULL,                   -- timestamp (centre of first pulse in detection);
                                             -- unix-style: seconds since 1 Jan 1970 GMT
    sig FLOAT(24) NOT NULL,                  -- signal strength, in dB (relative to max)
    sigSD FLOAT(24),                         -- standard deviation of signal strength, in dB (NULL
                                             -- okay; e.g. Lotek)
    noise FLOAT(24),                         -- noise level, in dB (relative to max) (NULL okay;
                                             -- e.g. Lotek)
    freq FLOAT(24),                          -- frequency offset, in kHz (NULL okay; e.g. Lotek)
    freqSD FLOAT(24),                        -- standard deviation of freq, in kHz (NULL okay;
                                             -- e.g. Lotek)
    slop FLOAT(24),                          -- discrepancy of pulse timing, in msec (NULL okay;
                                             -- e.g. Lotek)
    burstSlop FLOAT (24),                    -- discrepancy of burst timing, in msec (NULL okay;
                                             -- e.g. Lotek)
    runID INT NOT NULL,                      -- ID of run of bursts on this tag,
    posInRun INT NOT NULL,                   -- position of this burst in run of bursts for this tag
    runLen INT NOT NULL,                     -- length of run of this burst; 0 means run had not
                                             -- ended when this batch generated
    tsMotus FLOAT(53)                        -- timestamp when this record transferred to motus;
                                             -- NULL means not transferred
);

--  TABLE batches
-- 
--  each record describes a batch of hits; each batch comes from
--  running the sensorgnome tag finder code on data from a single
--  receiver, from a single boot period; it is not necessary that the
--  batch contain all detections from a single boot period, because we
--  want to be able to generate batches incrementally from a single
--  boot period, when data arrive in chunks throughout the season,
--  possibly without intervening reboots of the receiver.

CREATE TABLE batches (
    ID INT PRIMARY KEY UNIQUE NOT NULL, -- unique identifier for this batch
    motusRecvID INT NOT NULL,           -- ID for the receiver; foreign key to Motus DB table
    batchType VARCHAR(8) NOT NULL,      -- type of batch "hits", "gps", or "params"
    bootNum INT,                        -- boot number for this receiver;  (NULL okay; e.g. Lotek)
    tsBegin FLOAT(53) NOT NULL,         -- timestamp for start of period covered by batch;
                                        -- unix-style: seconds since 1 Jan 1970 GMT
    tsEnd FLOAT(53) NOT NULL,           -- timestamp for start of period covered by batch;
                                        -- unix-style: seconds since 1 Jan 1970 GMT
    numRec INT                          -- count of records in this batch
    ts FLOAT(53) NOT NULL,              -- timestamp when this batch record was added; unix-style:
                                        -- seconds since 1 Jan 1970 GMT
    tsMotus FLOAT(53)                   -- timestamp when this record transferred to motus;
                                        -- unix-style: seconds since 1 Jan 1970 GMT; NULL means not
                                        -- transferred
);

--  TABLE batchReplace
-- 
--  keep track of which batches replace earlier ones.  A new batch in
--  the transfer DB might replace one or more previous batches.  If
--  so, there is a record in this table for each batch being replaced.

CREATE TABLE batchReplace (
    oldBatchID INT NOT NULL, -- references batches, supposing we keep all those around
    newBatchID INT NOT NULL, -- references batches, 
    ts FLOAT(53) NOT NULL,   -- timestamp when this batch record was added; unix-style: seconds
                             -- since 1 Jan 1970 GMT
    tsMotus FLOAT(53)        -- timestamp when this record transferred to motus; NULL means not
                             -- transferred; unix-style: seconds since 1 Jan 1970 GMT
);

--  TABLE gps
-- 
--  record GPS fixes from a receiver

CREATE TABLE gps (
    batchID INT NOT NULL REFERENCES batches, -- ID of batch this gps fix belongs to
    ID INT NOT NULL,                         -- unique ID for this hit within this batch
    ts FLOAT(53) NOT NULL,                   -- timestamp for this fix, according to receiver;
                                             -- unix-style: seconds since 1 Jan 1970 GMT
    tsGPS FLOAT(53),                         -- timestamp for this fix, according to GPS;
                                             -- unix-style: seconds since 1 Jan 1970 GMT
    lat FLOAT(24),                           -- latitude, decimal degrees N
    lon FLOAT(24),                           -- longitude, decimal degrees E
    elev FLOAT(24),                          -- metres above local sea level
    tsMotus FLOAT(53)                        -- timestamp when this record transferred to motus; 0
                                             -- means not transferred; unix-style: seconds since 1
                                             -- Jan 1970 GMT
);

--  TABLE params
-- 
--  record receiver parameter settings, such as listening frequency and gain

CREATE TABLE params (
    batchID INT NOT NULL REFERENCES batches, -- ID of batch this gps fix belongs to
    ID INT NOT NULL,                         -- unique ID for this hit within this batch
    ts FLOAT(53) NOT NULL,                   -- timestamp for this setting; unix-style: seconds
                                             -- since 1 Jan 1970 GMT
    ant TINYINT NOT NULL,                    -- antenna number affected by this setting(USB Hub port
                                             -- # for SG; antenna port # for Lotek); 255 means all
    parID INT NOT NULL REFERENCES paramInfo, -- which parameter is being set, from a separate table
    parVal FLOAT(53) NOT NULL,               -- value of this parameter
    tsMotus FLOAT(53)                        -- timestamp when this record transferred to motus; 0
                                             -- means not transferred; unix-style: seconds since 1
                                             -- Jan 1970 GMT
);

--  TABLE paramInfo
-- 
--  maintains information about the different parameter settings possible on different receiver
--  types This is really just a set of constants, although the set might grow over time.

CREATE TABLE paramInfo (
    ID INT UNIQUE NOT NULL PRIMARY KEY,               -- ID of this parameter
    parName varchar(16) NOT NULL,                     -- name for this parameter
    parUnits varchar(16),                             -- units for this parameter, where relevant
    recvTypeID INT NOT NULL REFERENCES receiverTypes, -- type of receiver for which this parameter
                                                      -- is relevant
    tsMotus FLOAT(53)                                 -- timestamp when this record transferred to
                                                      -- motus; 0 means not transferred; unix-style:
                                                      -- seconds since 1 Jan 1970 GMT
);

