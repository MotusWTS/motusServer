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
    numRec INT,                         -- count of records in this batch
    ts FLOAT(53) NOT NULL,              -- timestamp when this batch record was added; unix-style:
                                        -- seconds since 1 Jan 1970 GMT
    tsMotus FLOAT(53)                   -- timestamp when this record transferred to motus;
                                        -- unix-style: seconds since 1 Jan 1970 GMT; NULL means not
                                        -- transferred
);

--  TABLE batchRunInfo
--
--  record info common across all hits in a tag run in each batch;

CREATE TABLE batchRunInfo (
    batchID INT NOT NULL REFERENCES batches, -- unique identifier of batch for this run
    runID INT NOT NULL,                      -- identifier of run within batch; this ID might be shared
                                             -- between different batches, if a run is split across
                                             -- multiple batches.  But it is unique for a given 
                                             -- (motusRecvID, bootNum).
    motusTagID INT NOT NULL,                 -- ID for the tag detected; foreign key to Motus DB table
    len INT,                                 -- length of run within batch
    tsMotus FLOAT(53),                       -- timestamp when this record transferred to motus;
                                             -- unix-style: seconds since 1 Jan 1970 GMT; NULL means not
                                             -- transferred
    PRIMARY KEY (batchID, runID)             -- only one length per (runID,batchID)
);

--  TABLE hits 
-- 
--  each record is a detection of a tag embedded in a run of such detections; runs track detections
--  of a tag by a single antenna on a single receiver.  Note: time-varying metadata about the
--  receiver (e.g. location) or radios (e.g. listening frequency, gain) are transferred separately
--  in the tables "gps" and "params"

CREATE TABLE hits (
    batchID INT NOT NULL REFERENCES batches, -- ID of batch this hit belongs to
    ID INT NOT NULL,                         -- unique ID for this hit within this batch
    ant TINYINT NOT NULL,                    -- antenna number (USB Hub port # for SG; antenna port
                                             -- # for Lotek)
    ts FLOAT(53) NOT NULL,                   -- timestamp (centre of first pulse in detection);
                                             -- unix-style: seconds since 1 Jan 1970 GMT
    sig FLOAT(24) NOT NULL,                  -- signal strength, in units appropriate to device;
                                             -- e.g.; for SG/funcube; dB (max); for Lotek: raw
                                             -- integer in range 0..255
    sigSD FLOAT(24),                         -- standard deviation of signal strength, in device
                                             -- units (NULL okay; e.g. Lotek)
    noise FLOAT(24),                         -- noise level, in device units (NULL okay; e.g. Lotek)
    freq FLOAT(24),                          -- frequency offset, in kHz (NULL okay; e.g. Lotek)
    freqSD FLOAT(24),                        -- standard deviation of freq, in kHz (NULL okay;
                                             -- e.g. Lotek)
    slop FLOAT(24),                          -- discrepancy of pulse timing, in msec (NULL okay;
                                             -- e.g. Lotek)
    burstSlop FLOAT (24),                    -- discrepancy of burst timing, in msec (NULL okay;
                                             -- e.g. Lotek)
    runID INT NOT NULL,                      -- ID of run of detections of this tag within this
                                             -- batch; this together with batchID references an entry
                                             -- in batchRunInfo
    posInRun INT NOT NULL,                   -- position of this detection in run of detections for
                                             -- this tag, numbered from 1; FIXME: could be removed.
    tsMotus FLOAT(53),                       -- timestamp when this record transferred to motus;
                                             -- NULL means not transferred
    PRIMARY KEY (batchID, ID),
    FOREIGN KEY (batchID, runID) references batchRunInfo(batchID, runID)
);


--  TABLE batchReplace
-- 
--  keep track of which batches replace earlier ones.  A new batch in
--  the transfer DB might replace one or more previous batches.  If
--  so, there is a record in this table for each batch being replaced.

CREATE TABLE batchReplace (
    oldBatchID INT PRIMARY KEY UNIQUE NOT NULL, -- references batches, supposing we keep all those
                                                -- around
    newBatchID INT NOT NULL,                    -- references batches,
    ts FLOAT(53) NOT NULL,                      -- timestamp when this batch record was added;
                                                -- unix-style: seconds since 1 Jan 1970 GMT
    tsMotus FLOAT(53)                           -- timestamp when this record transferred to motus;
                                                -- NULL means not transferred; unix-style: seconds
                                                -- since 1 Jan 1970 GMT
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
    tsMotus FLOAT(53),                       -- timestamp when this record transferred to motus; 0
                                             -- means not transferred; unix-style: seconds since 1
                                             -- Jan 1970 GMT
    PRIMARY KEY (batchID, ID)                                                                                                                     
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
    tsMotus FLOAT(53),                       -- timestamp when this record transferred to motus; 0
                                             -- means not transferred; unix-style: seconds since 1
                                             -- Jan 1970 GMT
    PRIMARY KEY (batchID, ID)                                                                                                                     
);

--  TABLE paramInfo
-- 
--  maintains information about the different parameter settings possible on different receiver
--  types.  This is really just a set of constants, although the set might grow over time.

CREATE TABLE paramInfo (
    ID INT UNIQUE NOT NULL PRIMARY KEY,               -- ID of this parameter
    parName varchar(16) NOT NULL,                     -- name for this parameter
    parUnits varchar(16),                             -- units for this parameter, where relevant
    devID INT NOT NULL REFERENCES devInfo,            -- type of device for which this parameter is
                                                      -- relevant
    tsMotus FLOAT(53)                                 -- timestamp when this record transferred to
                                                      -- motus; 0 means not transferred; unix-style:
                                                      -- seconds since 1 Jan 1970 GMT
);

-- TABLE deviceInfo
--
-- maintains information about the models of devices we use, such
-- as receivers and radios

CREATE TABLE devInfo (
    ID INT UNIQUE NOT NULL PRIMARY KEY, -- ID of this device
    devName VARCHAR(32),                -- human-readable name of device
    devType VARCHAR(32),                -- type of device: "radio", "receiver", ...
    mfg VARCHAR(32)                     -- manufacturer
);


-- initial values for receiverTypes and paramInfo

insert into devInfo (ID, devName, devType, mfg) values
       (0, "any", "receiver", ""),
       (1, "SensorGnome", "receiver", "sensorgnome.org"), 
       (2, "Lotek", "receiver", "lotek.com"), 
       (3, "SRX-600", "receiver", "lotek.com"),
       (4, "SRX-800", "receiver", "lotek.com"),
       (5, "SRX-DL", "receiver", "lotek.com"),
       (6, "FuncubeDonglePro", "radio", "funcubedongle.com"),  -- older model, only used by a few SGs
       (7, "FuncubeDonglePro+", "radio", "funcubedongle.com")  -- more recent (2013+) model
;

insert into paramInfo (ID, parName, parUnits, devID) values
    -- common to any receiver
       (0, "tunerFreq", "MHz", 0),

    -- Lotek-specific
       (1, "lotekGain", "nominal", 2),  
       
    -- funcubedongle Pro Plus params
       (2, "LNAGain", "on/off", 7), 
       (3, "mixerGain", "on/off", 7),
       (4, "RFFilter", "enum1-12", 7),
       (5, "IFGain", "dB0-59", 7),
       (6, "IFFilter", "enum1-8", 7)
;
