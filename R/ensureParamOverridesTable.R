#' make sure we have a valid parameterOverrides table
#'
#' The function takes no parameters.
#'
#' This table allows us to specify overrides to default parameters for the tag finder.
#' Ideally, these would be specified on the motus side, by receiver deployment,
#' but for now we do it like this.  For example, some projects operate on a listening
#' frequency of 150.1 MHz.  We need to specify that default frequency to the tag
#' finder in case the relevant frequency-setting records from the SG did not
#' make it into the data stream (usually because the user didn't send files with
#' pre-GPS dates like 2000-01-01).
#'
#' Each override can apply to either a particular receiver deployment, or to all
#' receiver deployments for a project.
#'
#' If the serno field is not null, the override is for a receiver deployment, given
#' by serno and either the timestamp range (tsStart, tsEnd) for Lotek receivers, or
#' the boot session range (monoBNlow, monoBNhigh) for SGs.  A range where the
#' second element (tsEnd or monoBNhigh) is null is treated as on-going.
#'
#' If the serno field is null but the projectID is not null, then the override applies
#' to all receivers for the specified project.  For SGs, only those boot sessions
#' where the receiver's deployment belonged to that project apply.
#'
#' FIXME: for Lotek receivers, the parameter overrides apply for the entire
#' sequence of data processed for this receiver.
#'
#' @return returns a \code{safeSQL} object to the override database
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}


ensureParamOverridesTable = function() {
    sql = safeSQL(MOTUS_PATH$PARAM_OVERRIDES)
    sql("
CREATE TABLE IF NOT EXISTS paramOverrides (
-- This table records parameter overrides by
-- receiver serial number and boot session range (SG)
-- or timestamp range (Lotek).  Alternatively,
-- the override can apply to all receiver deployments for
-- the specified projectID, and the given time range or monoBN range.

    projectID INT,                             -- project ID for this override;
    serno CHAR(32),                            -- serial number of device involved in this event (if any)
    tsStart FLOAT(53),                         -- starting timestamp for this override (Lotek only)
    tsEnd FLOAT(53),                           -- ending timestamp for this override (Lotek only)
    monoBNlow INT,                             -- starting boot session for this override (SG only)
    monoBNhigh INT,                            -- ending boot session for this override (SG only)
    progName VARCHAR(16) NOT NULL,             -- identifier of program; e.g. 'find_tags',
                                               -- 'lotek-plugins.so'
    paramName VARCHAR(16) NOT NULL,            -- name of parameter (e.g. 'minFreq')
    paramVal FLOAT(53),                        -- value of parameter (call be null if parameter is just a flag)
    why TEXT                                   -- human-readable reason for this override
);")
    sql("CREATE INDEX IF NOT EXISTS paramOverrides_serno ON paramOverrides(serno);")
    sql("CREATE INDEX IF NOT EXISTS paramOverrides_projectID ON paramOverrides(projectID);")
    return(sql)
}
