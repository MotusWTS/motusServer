## Interim Handling of Beeper Tags ##

(2018 March 8) Beeper tag support is still not complete.  For now, we
provide users with a database of pulses extracted from the raw
receiver data files.  This happens when the tag finder is run with th
`--pulses_only` option, e.g. via a project or receiver
parameterOverride.

### Format of SERNO_beeper.sqlite ###

This is an [sqlite](https://sqlite.org) file, which can be processed
in R via the `RSQLite` or `dplyr` packages.

The database contains two tables.  `params` records antenna parameter
settings, and has this schema:

```sql
CREATE TABLE params (
batchID INTEGER,      -- batchID this setting is from
ts      FLOAT(53),    -- timestamp for this record (seconds since 1 Jan 1970, GMT)
ant     INTEGER,      -- hub port for which device setting applies
param   VARCHAR,      -- parameter name
val     FLOAT(53),    -- parameter setting
error   INTEGER,      -- 0 if parameter setting succeeded; error code otherwise
errinfo VARCHAR       -- non-empty if error code non-zero
);
```

The `pulses` table contains detected pulses, and has this schema:
```sql
CREATE TABLE pulses (
   batchID INTEGER,    -- batchID these pulses belong to
   ts      FLOAT(53),  -- timestamp of pulse (seconds since 1 Jan 1970, GMT)
   ant     INTEGER,    -- antenna number
   antFreq FLOAT(53),  -- antenna tuner frequency (MHz)
   dfreq   FLOAT(53),  -- frequency offset of pulse (kHz)
   sig     FLOAT,      -- relative signal strength (dB max)
   noise   FLOAT       -- relative noise level (dB max)
);
```

The `params` table is mainly useful for verifying that setting and switching of
antenna frequency has worked correctly.  The frequency settings in `params`
are reflected in the `antFreq` field of the `pulses` table.

The `ts` fields are numeric timestamps.  You can convert (or rather *bless*) these
into datetime objects like so:

```R
library(dplyr)
t = tbl(src_sqlite("SG-5AA7RPI2D99F_beeper.sqlite"), "pulses")
p = as.data.frame(t)
class(p$ts) = class(Sys.time())
p[1:10,]
```
which gives:
```
   batchID                  ts ant antFreq dfreq    sig  noise
1        2 2017-08-06 19:10:52   1 150.169 4.612 -72.71 -76.83
2        2 2017-08-06 19:10:53   1 150.169 4.611 -72.14 -76.30
3        2 2017-08-06 19:10:54   1 150.169 4.612 -72.17 -76.97
4        2 2017-08-06 19:10:55   1 150.169 4.611 -72.46 -76.82
5        2 2017-08-06 19:11:00   1 150.169 4.610 -72.75 -77.07
6        2 2017-08-06 19:11:02   1 150.169 4.608 -73.16 -77.37
7        2 2017-08-06 19:11:07   1 150.169 4.606 -72.35 -76.84
8        2 2017-08-06 19:11:08   1 150.169 4.610 -71.91 -76.51
9        2 2017-08-06 19:25:40   1 150.169 4.726 -70.52 -76.93
10       2 2017-08-06 19:25:41   1 150.169 4.727 -71.69 -76.61
```
