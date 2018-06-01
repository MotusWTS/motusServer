# Notes on sgdata.motus.org problems from May, 2018 #

## (A) New frequency for Australia ##

**Problem**:  some Australian (and other) receivers have detected tags at the wrong frequency

**Cause**: failure of the mechanism by which the tag finder knows what frequency the
receiver is listening on.

### Normal Operation ###

1. the tag finder keeps track of what frequency an antenna is tuned to, and only seeks tags with
  that nominal frequency.  e.g. 166.38 vs. 150.4 MHz

2. funcubes or rtlsdrs are tuned to the listening frequency shortly after boot time, when the
  sensorgnome starts the "master process" (the one that reads deployment.txt to know what
  to do).

3. normally, this frequency setting event is recorded in the data stream.  But (bug) it
  sometimes isn't.  In that case, the tag finder needs to have a fallback default listening
  frequency so that it's searching for the right subset of tags.

4. in the Americas, the fallback listening frequency is 166.376 MHz; in other places, it
  may need to bet set to something else (e.g. 150.1 in Germany; 150.4 in Australia).

5. the default listening frequency is a parameter to the tag finder, and can be changed
  for a project or for specific receivers by a **parameter override**

6. parameter overrides exist in a database managed on the data processing server,
  and are looked-up by projectID and/or receiver serial number (and possibly by
  range of dates or boot numbers of the data to be processed)

7. there will soon be a set of API calls by which the parameter
  overrides can be queried, set, and deleted.  For now, they can be
  maniuplated manually from the command line on sgdata.motus.org
  using, e.g.
```sql
sqlite3 /sgm_local/motus_meta_db.sqlite
SQLite version 3.16.2 2017-01-06 16:32:41
Enter ".help" for usage hints.
sqlite> .schema paramOverrides
CREATE TABLE paramOverrides (
-- This table records parameter overrides by
-- receiver serial number and boot session range (SG)
-- or timestamp range (Lotek).  Alternatively,
-- the override can apply to all receiver deployments for
-- the specified projectID, and the given time range or monoBN range.

    id INTEGER PRIMARY KEY NOT NULL,           -- unique ID for this override
    projectID INT,                             -- project ID for this override
    serno CHAR(32),                            -- serial number of device involved in this event (if any)
    tsStart FLOAT(53),                         -- starting timestamp for this override
    tsEnd FLOAT(53),                           -- ending timestamp for this override
    monoBNlow INT,                             -- starting boot session for this override
    monoBNhigh INT,                            -- ending boot session for this override
    progName VARCHAR(16) NOT NULL,             -- identifier of program; e.g. 'find_tags_motus'
    paramName VARCHAR(16) NOT NULL,            -- name of parameter (e.g. 'default_freq')
    paramVal FLOAT(53),                        -- value of parameter (call be null if parameter is just a flag)
    why TEXT                                   -- human-readable reason for this override
);
CREATE INDEX paramOverrides_serno ON paramOverrides(serno);
CREATE INDEX paramOverrides_projectID ON paramOverrides(projectID);
sqlite> select * from paramOverrides where projectID=177;  -- for Australian project
59|177||||||find_tags_motus|default_freq|151.5|project frequency for all 2018 tags
```

So this can fail if the tag finder can't figure out what project a receiver belongs to,
or if there is no parameter override registered for that project.  Either of these can
happen due to stale metadata (see topic (B) below)

One thing I just changed yesterday is that now, if there is no other source of information
about a receiver, the tag finder will use the ID of the project which has been selected
by the user who uploaded the data.  This will cover cases where a user registers a
receiver with a project then immediately uploads data for processing, before the
metadata cache on the processing server has been updated (which happens only once daily),
provided a `default_freq` parameter override has been created for that project.

**Follow-up:** I believe all data affected by a missing parameter override for Australia
have been re-run with that corrected.

## (B) Stale Metadata ##

**Problem:** recently-registered tags are not showing up in data from receivers where
they are known to be present.

**Cause:** the tag finder is working with an old (stale) version of
tag metadata that doesn't include the newly-registered tags.  The tag
finder only searches for (and so only detects) tags it knows are
active.

### Normal Operation ###

1. each morning at 8:30 GMT, the sgdata.motus.org queries the motus.org server for all
tag and receiver metadata, which it stores in a cache.

2. a log of any changes to the metadata is pushed to the github repository
   https://github.com/jbrzusto/motus-metadata-history

3. any data run that day use the version of tag meta obtained that morning, and record
a checksum identifying that version in the receiver DB.

So this can fail if the refresh of the metadata cache fails to run,
due to problems on either server.  The most recent case of this was
due to a but in the post-installation function of the motusServer
package on sgdata.motus.org, which left broken links to the daily
update job, so that it failed to run.

Ultimately, it would be better if updates to motus.org metadata were
pushed directly to sgdata.motus.org via an API call, so that we didn't
have the artificial delay of up to 1 day before changes to metadata
were propagated.  The only other way to eliminate that delay right now
would be for the tag finder to request a full set of metadata from
motus.org each time it runs, which is fairly inefficient, especially
once online receivers are being run hourly.

**Follow-up**: I need to dig back and find all the jobs affected by
this bug, and re-run them.  Also, the installation bug needs to be
fixed so that the daily metadata update doesn't break again.
