[**Note:** All of these APIs which used to use these queries run
quickly as of Sept. 19, 2017, due to addition of fields to some tables,
creation of some compound indexes, and restructuring of the queries.
This document is added to the repo for the record.]

## Examples of very slow queries (up to Sept. 18, 2017) ##

The main issue is how many rows are being examined, given that
the maximum number we actually want is 10000.

### batches_for_tag_project ###
```
# Time: 170917 15:50:17
# User@Host: motus[motus] @ localhost []
# Thread_id: 7683  Schema: motus  QC_hit: No
# Query_time: 104.897309  Lock_time: 0.000114  Rows_sent: 0  Rows_examined: 40274471
```
```SQL
SET timestamp=1505663417;
select
   t1.batchID,
   t1.motusDeviceID,
   t1.monoBN,
   t1.tsStart,
   t1.tsEnd,
   t1.numHits,
   t1.ts,
   t1.motusUserID,
   t1.motusProjectID,
   t1.motusJobID
from
   batches as t1
where
   t1.batchID > 101733
   and
   exists (
      select
         *
      from
         batchRuns as t2
      join
         runs as t3 on t3.runID=t2.runID
      where
         t2.batchID=t1.batchID
         and t3.tagDepProjectID = 7
   )
order by
   t1.batchID
limit 10000;
```

### hits_for_tag_project ###

```
# Time: 170917 16:46:31
# User@Host: motus[motus] @ localhost []
# Thread_id: 7683  Schema: motus  QC_hit: No
# Query_time: 124.483162  Lock_time: 0.000125  Rows_sent: 10000  Rows_examined: 7589845
```
```SQL
select
   t1.hitID,
   t1.runID,
   t1.batchID,
   t1.ts,
   t1.sig,
   t1.sigSD,
   t1.noise,
   t1.freq,
   t1.freqSD,
   t1.slop,
   t1.burstSlop
from
   hits as t1
   join runs as t2 on t2.runID = t1.runID
   join batchRuns as t3 on t3.runID = t2.runID
where
   ((t2.runID = 10825197 and t1.hitID > 209611467)
    or (t2.runID > 10825197))
   and t3.batchID = 68902
   and t2.tagDepProjectID = 14
order by
   t2.runID, t1.hitID
limit 10000;
```
Without the t1.hitID ordering subterm, the query runs much faster.  Why?



### runs_for_tag_project ###

```
# Time: 170917 16:35:00
# User@Host: motus[motus] @ localhost []
# Thread_id: 7683  Schema: motus  QC_hit: No
# Query_time: 15.725335  Lock_time: 0.000106  Rows_sent: 10000  Rows_examined: 925889

```
```SQL
SET timestamp=1505666100;
select
   t1.runID,
   t1.batchIDbegin,
   t1.tsBegin,
   t1.tsEnd,
   t1.done,
   t1.motusTagID,
   t1.ant,
   t1.len
from
   runs as t1
   join batchRuns as t2 on t1.runID=t2.runID
where
   t2.batchID = 68902
   and t1.runID > 0
   and t1.tagDepProjectID = 14
order by
   t1.runID
limit 10000;

```

### gps_for_tag_project ###

```
# Time: 170919 14:08:31
# User@Host: motus[motus] @ localhost []
# Thread_id: 26  Schema: motus  QC_hit: No
# Query_time: 107.341567  Lock_time: 0.000163  Rows_sent: 49  Rows_examined: 3481505
# Rows_affected: 0
```
```SQL
SET timestamp=1505830111;
select
    t1.ts,
    t1.gpsts,
    t1.batchID,
    t1.lat,
    t1.lon,
    t1.alt
from
   gps as t1
   join (
      select
         min(t3.tsBegin) as tsBegin,
         max(t3.tsEnd) as tsEnd
      from
         batchRuns as t2
         join runs as t3 on t3.runID = t2.runID
      where
         t2.batchID = 68902
         and t3.tagDepProjectID = 14
    ) as t4
where
   t1.batchID = 68902
   and t1.ts > 0.000000
   and t1.ts >= t4.tsBegin - 3600
   and t1.ts <= t4.tsEnd + 3600
order by
   t1.ts
limit 10000;
```
