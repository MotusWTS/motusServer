#' Fix https://github.com/jbrzusto/motusServer/issues/251
#'
#' i.e. repush the records from each receiver DB's batchParams table
#' for the parameter "metadata_hash" of program "find_tags_motus"
#'
#' This is a one-time repair job.

library(motusServer)

openMotusDB()

for (serno in dir(MOTUS_PATH$FILE_REPO)) {
    src = getRecvSrc(serno)
    sql = safeSQL(src)
    hpar = sql("
select
   t1.batchID + t2.offsetBatchID as bid,
   t1.paramVal as val
from
   batchParams as t1
   join motusTX as t2 on t1.batchID=t2.batchID
where
   t1.paramName='metadata_hash'
")
    for (i in seq(along = hpar$bid)) {
        MotusDB("
replace into
   batchParams
values (
   %d,
   'find_tags_motus',
   'metadata_hash',
   %s)
",
hpar$bid[i], hpar$val[i])
    }
    cat(serno)
}
