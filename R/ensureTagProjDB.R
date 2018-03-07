#' make sure a tag project database has the required tables; also, load
#' custom SQLite extensions on this DB connection.
#'
#' @param src dplyr sqlite src, as returned by \code{dplyr::src_sqlite()}
#'
#' @param recreate vector of table names which should be dropped then re-created,
#' losing any existing data.  Defaults to empty vector, meaning no tables
#' are recreate.  As a special case, TRUE causes all tables to be dropped
#' then recreated.
#'
#' @param projectID motus project ID; this DB will hold tag detections from
#' one motus project
#'
#' @return returns NULL (silently); fails on any error
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ensureTagProjDB = function(src, recreate=c(), projectID) {
    if (! inherits(src, "src_sql"))
        stop("src is not a dplyr::src_sql object")
    con = src$con
    if (! inherits(con, "SQLiteConnection"))
        stop("src is not open or is corrupt; underlying db connection invalid")

    ## function to send a single statement to the underlying connection
    sql = function(...) dbGetQuery(con, sprintf(...))

    sql("pragma page_size=4096") ## reasonably large page size; post 2011 hard drives have 4K sectors anyway

    if (isTRUE(recreate))
        recreate = sgTableNames

    ## load custom extensions
    sql("select load_extension('%s')",  system.file(paste0("libs/Sqlite_Compression_Extension", .Platform$dynlib.ext), package="motusServer"))

    for (t in recreate)
        sql("drop table %s", t)

    tables = src_tbls(src)

    if (all(tagProjTableNames %in% tables))
        return()

    if (! "meta" %in% tables) {
        sql("
create table meta (
key  character not null unique primary key, -- name of key for meta data
val  character                              -- character string giving meta data; might be in JSON format
)
");
    }

    if (! "tagAmbig" %in% tables) {
        sql("
CREATE TABLE tagAmbig (
    ambigID INTEGER PRIMARY KEY NOT NULL,  -- identifier of group of tags which are ambiguous (identical); will be negative
    masterAmbigID INTEGER,                 -- master ID of this ambiguity group, once different receivers have been combined
    motusTagID1 INT NOT NULL,              -- motus ID of tag in group (not null because there have to be at least 2)
    motusTagID2 INT NOT NULL,              -- motus ID of tag in group.(not null because there have to be at least 2)
    motusTagID3 INT,                       -- motus ID of tag in group.
    motusTagID4 INT,                       -- motus ID of tag in group.
    motusTagID5 INT,                       -- motus ID of tag in group.
    motusTagID6 INT                        -- motus ID of tag in group.
);
")
        sql( "create unique index tagAmbig_motusTagID on tagAmbig(motusTagID1, motusTagID2, motusTagID3, motusTagID4, motusTagID5, motusTagID6)")
    }


    if (! "batches" %in% tables) {
        sql("
CREATE TABLE batches (
    batchID INTEGER PRIMARY KEY,              -- unique identifier for this batch
    motusDeviceID INTEGER,                    -- motus ID of this receiver (NULL means not yet
                                              -- registered or not yet looked-up)  In a receiver
                                              -- database, this will be a constant column, but
                                              -- that way it has the same schema as in the master
                                              -- database.
    monoBN INT,                               -- boot number for this receiver; (NULL
                                              -- okay; e.g. Lotek)
    tsStart FLOAT(53),                        -- timestamp for start of period
                                              -- covered by batch; unix-style:
                                              -- seconds since 1 Jan 1970 GMT
    tsEnd FLOAT(53),                          -- timestamp for end of period
                                              -- covered by batch; unix-style:
                                              -- seconds since 1 Jan 1970 GMT
    numHits BIGINT,                           -- count of hits in this batch
    ts FLOAT(53),                             -- timestamp when this batch record was
                                              -- added; unix-style: seconds since 1
                                              -- Jan 1970 GMT
    motusUserID INT,                          -- user who uploaded the data leading to this batch
    motusProjectID INT,                       -- user-selected motus project ID for this batch
    motusJobID INT                            -- job whose processing generated this batch
);
")
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
                                                      -- # for Lotek); 11 means Lotek master antenna 'A1+A2+A3+A4'
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
    ## make sure this DB is labelled as a tag project

    sql("insert or replace into meta values ('dbType', 'tagProject')")
    sql("insert or replace into meta values ('projectID', '%s')", projectID)
}

## list of tables needed in the receiver database

tagProjTableNames = c("meta", "batches", "runs", "hits", "tagAmbig")
