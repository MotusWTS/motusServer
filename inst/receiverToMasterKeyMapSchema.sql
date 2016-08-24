-- Tables to map keys between receiver database tables and master
-- database tables.  Receiver database tables are created
-- independently of each other, without centralized coordination
-- (except for using motus receiver and tag IDs).  When combining data
-- from different receivers, we must remap to new keys to avoid
-- collisions between receivers.  One approach would be to use
-- compound keys that include the receiver ID, but this is bulky and
-- awkward, forcing a new column into large tables (runs, hits).
-- Instead, we opt to generate new unique keys to represent batches,
-- runs, hits, etc.  when data are pushed to the transfer database,
-- and create mapping tables that keep track of the relationship, in
-- case we need to trace back a detection from the master database to
-- a receiver database.

-- We keep one table per key type.

-- map between master and receiver batch IDs.

CREATE TABLE IF NOT EXISTS batchIDMap (
    batchID INT NOT NULL REFERENCES batches,  -- value of the master batchID
    recvBatchID INT NOT NULL,                 -- foreign key to receiver database batches table
    PRIMARY KEY (batchID)
);----


CREATE TABLE IF NOT EXISTS runIDMap (
    runID BIGINT NOT NULL REFERENCES runs, -- value of the master runID
    recvRunID INT NOT NULL,                -- foreign key to receiver database runs table
    PRIMARY KEY (motusRecvID, runID, recvRunID)
);----


CREATE TABLE IF NOT EXISTS hitIDMap (
    motusRecvID INTEGER NOT NULL,          -- motus ID of receiver; foreign key to Motus DB table.
    hitID BIGINT NOT NULL REFERENCES hits, -- value of the master hitID
    recvHitID BIGINT NOT NULL,             -- foreign key to receiver database hits table
    PRIMARY KEY (motusRecvID, hitID, recvHitID)
);----


CREATE TABLE IF NOT EXISTS ambigIDMap (
    motusRecvID INTEGER NOT NULL,               -- motus ID of receiver; foreign key to Motus DB table.
    ambigID INT NOT NULL REFERENCES batchAmbig, -- value of the master ambigID
    recvAmbigID INT NOT NULL,                   -- foreign key to receiver database batchAmbig table
    PRIMARY KEY (motusRecvID, ambigID, recvAmbigID)
);----

