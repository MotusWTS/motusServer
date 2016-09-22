#' run the tag finder on one sensorgnome boot session, in the new style.
#'
#' Called by \code{\link{server}}.
#'
#' Runs the new tag finder for one boot session of a single SG.
#' The files for that boot session have already been merged into
#' the DB for that receiver.
#'
#' @param path ignored
#'
#' @param isdir boolean; TRUE iff the path is a directory; must be FALSE
#'
#' @param params character vector of parameters:
#' \itemize{
#' \item serno serial number of receiver (including leading 'SG-')
#' \item monoBN monotonic boot session number; if missing, run all boot sessions
#' for this receiver.
#' \item boolean TRUE or FALSE; can the tag finder be run with \code{--resume}?
#' If monoBN is omitted, this parameter must also be.
#' }
#'
#' @return TRUE
#' 
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleSGnew = function(path, isdir, params) {
    if (isdir || ! length(params) %in% c(1, 3)) return (FALSE)

    serno = params[1]
    ## FIXME: at some point, all sernos in this package should include the 'SG-' prefix

    if (substr(serno, 1, 3) != "SG-")
        serno = paste0("SG-", serno)
    if (length(params) == 3) {
        monoBN = as.integer(params[2])
        canResume = as.logical(params[3])
        sgFindTags(sgRecvSrc(serno), getMotusMetaDB(), resume=canResume, mbn=monoBN)
    } else {
        sgFindTags(sgRecvSrc(serno), getMotusMetaDB())
    }
    return(TRUE)
}
