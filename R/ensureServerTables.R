#' ensure we have database tables for running the server.
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

ensureServerTables = function(recreate=c()) {
    src = src_sqlite(MOTUS_SERVER_DB, TRUE)
    con = src$con

    ## function to send a single statement to the underlying connection
    sql = function(...) dbGetQuery(con, sprintf(...))

    sql("pragma busy_timeout=10000")
    sql("pragma page_size=4096") ## reasonably large page size; post 2011 hard drives have 4K sectors anyway

    if (isTRUE(recreate))
        recreate = serverTableNames

    for (t in recreate)
        sql("drop table %s", t)

    tables = src_tbls(src)

    if (all(serverTableNames %in% tables))
        return()

    if (! "jobs" %in% tables) {
        sql("
CREATE TABLE jobs (
  id       INTEGER UNIQUE PRIMARY KEY NOT NULL, -- id of this job
  ts       FLOAT(53),                           -- job creation date (unix timestamp)
  tsLast   FLOAT(53),                           -- last change date (unix timestamp)
  complete INT,                                 -- 1 if done; 0 if not
  info     TEXT                                 -- JSON string with job info
);
")
        sql("CREATE INDEX jobs_complete on jobs(complete)")
    }

    if (! "jobSteps" %in% tables) {
        sql("
CREATE TABLE jobSteps (
  id       INTEGER UNIQUE PRIMARY KEY NOT NULL, -- id of this step
  ts       FLOAT(53),                           -- job creation date (unix timestamp)
  tsLast   FLOAT(53),                           -- last change date (unix timestamp)
  complete INT,                                 -- 1 if done, 0 if not
  jobID    INT REFERENCES jobs(id),             -- id of parent job
  info     TEXT,                                -- JSON string with job step info
  errors   TEXT                                 -- JSON string with error info
);
")
        sql("CREATE INDEX jobSteps_jobID on jobSteps(jobID)")
    }
}

## list of tables needed in the receiver database

serverTableNames = c("jobs", "jobSteps")
