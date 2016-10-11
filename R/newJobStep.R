#' create a new job step.
#'
#' A new unique jobStep # is generated, and a folder for it is added
#' to the folder of the parent job. An entry in the server database is
#' created.
#'
#' @param job object of class "motusJob"
#'
#' @param type name of handler for this job step
#'
#' @param params R object representable in JSON
#'
#' @return This function returns a named integer vector of length 1
#'     with class "motusJobStep".  The value is the job step number,
#'     and the name is the full path to the new folder.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

newJobStep = function(job, type, params) {
    ts = as.numeric(Sys.time())
    json = unclass(toJSON(list(type=type, params=params), auto_unbox=TRUE, POSIXt="epoch", digits=I(18)))
    sql = safeSQL(MOTUS_SERVER_DB)
    sql("insert into jobSteps (ts, jobID, complete, info) values (:ts, :jobID, 0, :info)",
        ts=ts, jobID = as.integer(job), info=json)
    ## get the ID of the new jobStep
    id = sql("select last_insert_rowid()")[[1]]
    sql(.CLOSE=TRUE)
    np = file.path(names(job), sprintf("%08d", id))
    dir.create(np)
    return(structure(id, names=np, class="motusJobStep"))
}
