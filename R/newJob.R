#' create a new job.
#'
#' A new unique job # is generated, and a folder for it is added to /sgm/queue/0
#' An entry in the server database is created.
#'
#' @param type character scalar name of job handler
#'
#' @param params R object representable in JSON
#'
#' @return This function returns a named integer vector of length 1
#'     with class "motusJob".  The value is the job number, and the
#'     name is the full path to the new folder.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

newJob = function(type, params) {
    ts = as.numeric(Sys.time())
    json = unclass(toJSON(list(type=type, params=params), auto_unbox=TRUE, POSIXt="epoch", digits=I(18)))
    sql = safeSQL(MOTUS_SERVER_DB)
    sql("insert into jobs (ts, complete, info) values (:ts, 0, :info)",
        ts=ts, info=json)
    ## get the ID of the new job
    id = sql("select last_insert_rowid()")[[1]]
    sql(.CLOSE=TRUE)
    np = file.path(MOTUS_PATH$QUEUE0, sprintf("%08d", id))
    dir.create(np)
    return(structure(id, names=np, class="motusJob"))
}
