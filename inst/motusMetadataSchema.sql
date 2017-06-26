-- schema for metadata tables obtained from motus.org

CREATE TABLE IF NOT EXISTS tags  (
   "tagID" INTEGER PRIMARY KEY NOT NULL,
   "projectID" INTEGER,
   "mfgID" TEXT,
   "dateBin" TEXT,
   "type" TEXT,
   "codeSet" TEXT,
   "manufacturer" TEXT,
   "model" TEXT,
   "lifeSpan" INTEGER,
   "nomFreq" REAL,
   "offsetFreq" REAL,
   "period" REAL,
   "periodSD" REAL,
   "pulseLen" REAL,
   "param1" REAL,
   "param2" REAL,
   "param3" REAL,
   "param4" REAL,
   "param5" REAL,
   "param6" REAL,
   "param7" INTEGER,
   "param8" INTEGER,
   "tsSG" REAL,
   "approved" INTEGER,
   "deployID" INTEGER,
   "status" TEXT,
   "tsStart" REAL,
   "tsEnd" REAL,
   "deferSec" INTEGER,
   "speciesID" INTEGER,
   "markerNumber" TEXT,
   "markerType" TEXT,
   "latitude" REAL,
   "longitude" REAL,
   "elevation" REAL,
   "comments" TEXT,
   "id" INTEGER,
   "bi" REAL,
   "tsStartCode" INTEGER,
   "tsEndCode" INTEGER
);

CREATE TABLE IF NOT EXISTS events  (
   "ts" REAL,
   "tagID" INTEGER,
   "event" INTEGER
);
CREATE INDEX IF NOT EXISTS events_ts on events(ts);

CREATE TABLE IF NOT EXISTS projs  (
   "id" INTEGER PRIMARY KEY NOT NULL,
   "name" TEXT,
   "label" TEXT,
   "tagsPermissions" INTEGER,
   "sensorsPermissions" INTEGER
);

CREATE TABLE IF NOT EXISTS tagDeps  (
   "tagID" INTEGER,
   "projectID" INTEGER,
   "deployID" INTEGER,
   "status" TEXT,
   "tsStart" REAL,
   "tsEnd" REAL,
   "deferSec" INTEGER,
   "speciesID" INTEGER,
   "markerNumber" TEXT,
   "markerType" TEXT,
   "latitude" REAL,
   "longitude" REAL,
   "elevation" REAL,
   "comments" TEXT,
   "id" INTEGER,
   "bi" REAL,
   "tsStartCode" INTEGER,
   "tsEndCode" INTEGER,
   "fullID" TEXT
);
CREATE INDEX IF NOT EXISTS tagDeps_tagID on tagDeps (tagID);
CREATE INDEX IF NOT EXISTS tagDeps_projectID on tagDeps (projectID);
CREATE INDEX IF NOT EXISTS tagDeps_deployID on tagDeps (deployID);

CREATE TABLE IF NOT EXISTS recvDeps  (
   "id" INTEGER,
   "serno" TEXT,
   "receiverType" TEXT,
   "deviceID" INTEGER,
   "macAddress" TEXT,
   "status" TEXT,
   "deployID" INTEGER,
   "name" TEXT,
   "fixtureType" TEXT,
   "latitude" REAL,
   "longitude" REAL,
   "isMobile" INTEGER,
   "tsStart" REAL,
   "tsEnd" REAL,
   "projectID" INTEGER,
   "elevation" REAL
);
CREATE INDEX IF NOT EXISTS recvDeps_deviceID on recvDeps (deviceID);
CREATE INDEX IF NOT EXISTS recvDeps_projectID on recvDeps (projectID);
CREATE INDEX IF NOT EXISTS recvDeps_deployID on recvDeps (deployID);

CREATE TABLE IF NOT EXISTS antDeps  (
   "deployID" INTEGER,
   "port" INTEGER,
   "antennaType" TEXT,
   "bearing" REAL,
   "heightMeters" REAL,
   "cableLengthMeters" REAL,
   "cableType" TEXT,
   "mountDistanceMeters" REAL,
   "mountBearing" REAL,
   "polarization2" REAL,
   "polarization1" REAL
);
CREATE INDEX IF NOT EXISTS antDeps_deployID on antDeps (deployID);

CREATE TABLE IF NOT EXISTS "paramOverrides" (
   "projectID" INTEGER,
   "serno" TEXT,
   "tsStart" REAL,
   "tsEnd" REAL,
   "monoBNlow" INTEGER,
   "monoBNhigh" INTEGER,
   "progName" TEXT,
   "paramName" TEXT,
   "paramVal" REAL,
   "why" TEXT
);

CREATE INDEX IF NOT EXISTS paramOverrides_projectID on paramOverrides (projectID);
CREATE INDEX IF NOT EXISTS paramOverrides_serno on paramOverrides (serno);

CREATE TABLE IF NOT EXISTS species (
   "id" INTEGER PRIMARY KEY NOT NULL,
   "english" TEXT,
   "french" TEXT,
   "scientific" TEXT,
   "group" TEXT,
   "sort" INTEGER
);

CREATE TABLE IF NOT EXISTS "recvGPS" (
   "deviceID" INTEGER,
   "ts" REAL,
   "lat" REAL,
   "lon" REAL,
   "elev" REAL,
   PRIMARY KEY ("deviceID", "ts")
);
