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
    ID BIGINT PRIMARY KEY UNIQUE NOT NULL,                   -- unique identifier for this batch
    motusRecvID INT NOT NULL,                                -- ID for the receiver; foreign key to
                                                             -- Motus DB table
    batchType VARCHAR(8) NOT NULL,                           -- type of batch "hits", "gps", or
                                                             -- "params"
    bootNum INT,                                             -- boot number for this receiver; (NULL
                                                             -- okay; e.g. Lotek)
    tsBegin FLOAT(53) NOT NULL,                              -- timestamp for start of period
                                                             -- covered by batch; unix-style:
                                                             -- seconds since 1 Jan 1970 GMT
    tsEnd FLOAT(53) NOT NULL,                                -- timestamp for end of period
                                                             -- covered by batch; unix-style:
                                                             -- seconds since 1 Jan 1970 GMT
    numRec INT,                                              -- count of records in this batch
    ts FLOAT(53) NOT NULL,                                   -- timestamp when this batch record was
                                                             -- added; unix-style: seconds since 1
                                                             -- Jan 1970 GMT
    swInfoSet INT NOT NULL REFERENCES batchSWInfoSet (ID),   -- software versions used to generate
                                                             -- this batch
    swParamSet INT NOT NULL REFERENCES batchSWParamSet (ID), -- parameter set for software used to
                                                             -- generate this batch
    tsMotus FLOAT(53)                                        -- timestamp when this record
                                                             -- transferred to motus; unix-style:
                                                             -- seconds since 1 Jan 1970 GMT; NULL
                                                             -- means not transferred
                                                             -- If set, this means all records from batchRunInfo,
                                                             -- hits, gps, and params which form part of this batch have
                                                             -- already been transferred.

);

--  TABLE batchRunInfo
--
--  record info common across all hits in a tag run in each batch;

CREATE TABLE batchRunInfo (
    runID BIGINT NOT NULL PRIMARY KEY,       -- identifier of run; globally uique ID
    batchID BIGINT NOT NULL REFERENCES batches, -- unique identifier of batch for this run
    motusTagID INT NOT NULL,                 -- ID for the tag detected; foreign key to Motus DB
                                             -- table
    len INT,                                 -- length of run within batch
    tsMotus FLOAT(53),                       -- timestamp when this record transferred to motus;
                                             -- unix-style: seconds since 1 Jan 1970 GMT; NULL means
                                             -- not transferred; if this timestamp is set, it means
                                             -- all the hits for the run have also been transferred
);

--  TABLE hits 
-- 
--  each record is a detection of a tag embedded in a run of such detections; runs track detections
--  of a tag by a single antenna on a single receiver.  Note: time-varying metadata about the
--  receiver (e.g. location) or radios (e.g. listening frequency, gain) are transferred separately
--  in the tables "gps" and "params"

CREATE TABLE hits (
    hitID BIGINT NOT NULL PRIMARY KEY              -- unique ID of this hit
    runID BIGINT NOT NULL REFERENCES batchRunInfo, -- ID of batch this hit belongs to
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
    GPSID BIGINT NOT NULL PRIMARY KEY,          -- unique key of this GPS record
    batchID BIGINT NOT NULL REFERENCES batches, -- ID of batch this gps fix belongs to
    ts FLOAT(53) NOT NULL,                      -- timestamp for this fix, according to receiver;
                                                -- unix-style: seconds since 1 Jan 1970 GMT
    tsGPS FLOAT(53),                            -- timestamp for this fix, according to GPS;
                                                -- unix-style: seconds since 1 Jan 1970 GMT
    lat FLOAT(24),                              -- latitude, decimal degrees N
    lon FLOAT(24),                              -- longitude, decimal degrees E
    elev FLOAT(24)                              -- metres above local sea level
);

--  TABLE params
-- 
--  record receiver parameter settings, such as listening frequency and gain

CREATE TABLE params (
    paramID BIGINT NOT NULL PRIMARY KEY,     -- unique ID for this param record
    batchID BIGINT NOT NULL REFERENCES batches, -- ID of batch this gps fix belongs to
    ts FLOAT(53) NOT NULL,                   -- timestamp for this setting; unix-style: seconds
                                             -- since 1 Jan 1970 GMT
    ant TINYINT NOT NULL,                    -- antenna number affected by this setting(USB Hub port
                                             -- # for SG; antenna port # for Lotek); 255 means all
    parID INT NOT NULL REFERENCES paramInfo, -- which parameter is being set, from a separate table
    parVal FLOAT(53) NOT NULL                -- value of this parameter
);

--  TABLE batchSWInfoSet
--
--  maintains information about the versions of software used to generate a batch.
--  Typically, large numbers of batches will be run with the same versions of the
--  software, so we organize software version records into infoSets, and associate
--  one of those with each batch.
--

CREATE TABLE batchSWInfoSet (
    ID INT NOT NULL,                         -- identifier of a set of software versions
    progName VARCHAR(16) NOT NULL,           -- identifier of program; e.g. "find_tags",
                                             -- "lotek-plugins.so"
    progVersion CHAR(40) NOT NULL,           -- git commit hash for version of code used
    progBuildTS FLOAT(53) NOT NULL,          -- timestamp of binary for this program; unix-style:
                                             -- seconds since 1 Jan 1970 GMT; NULL means not
                                             -- transferred
    tsMotus FLOAT(53),                       -- timestamp when this record transferred to motus;
                                             -- unix-style: seconds since 1 Jan 1970 GMT; NULL means
                                             -- not transferred
    PRIMARY KEY (ID, progName)               -- only one version of a given program per infoSet
);


--  TABLE batchSWParamSet
--
--  maintains information about the parameter values used by programs in a batch run.  Typically,
--  large numbers of batches will be run with the same values of the parameters, so we organize
--  parameter value records into paramSets, and associate one of those with each batch.
--

CREATE TABLE batchSWParamSet (
    ID INT NOT NULL,                         -- identifier of a set of parameters
    progName VARCHAR(16) NOT NULL,           -- identifier of program; e.g. "find_tags",
                                             -- "lotek-plugins.so"
    parName varchar(16) NOT NULL,            -- name of parameter (e.g. "--minFreq")
    parVal FLOAT(53) NOT NULL,               -- value of parameter
    tsMotus FLOAT(53),                       -- timestamp when this record transferred to motus;
                                             -- unix-style: seconds since 1 Jan 1970 GMT; NULL means
                                             -- not transferred
    PRIMARY KEY (ID, progName, parName)      -- only one value of a given parameter per program per
                                             -- param set
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
