#' register a tag with motus
#'
#' @param projectID: integer scalar; motus internal project ID
#'
#' @param mfgID: character scalar; typically a small integer; return
#'     only records for tags with this manufacturer ID (usually
#'     printed on the tag)
#'
#' @param type: character scalar; tag type; "ID" or "beeper"
#' 
#' @param codeSet: character scalar; manufacturer's codeset label,
#'     when \code{type} is "ID"
#'
#' @param offsetFreq: numeric scalar; offset of tag frequency from
#'     nominal, in kHz
#'
#' @param period: numeric scalar; repeat interval of tag transmission,
#'     in seconds.
#'
#' @param periodSD: numeric scalar; standard deviation of period
#'
#' @param pulseLen: numeric scalar; length of pulses emitted by tag,
#'     in milliseconds
#' 
#' @param param1: numeric scalar; first measured tag parameter; for
#'     Lotek coded ID, this is the first interpulse gap
#'
#' @param param2: numeric scalar; second measured tag parameter; for
#'     Lotek coded ID, this is the second interpulse gap
#'
#' @param param3: numeric scalar; third measured tag parameter; for
#'     Lotek coded ID, this is the third interpulse gap
#'
#' @param param4: numeric scalar; fourth measured tag parameter; for
#'     Lotek coded ID, this is the standard deviation of the first
#'     interpulse gap
#'
#' @param param5: numeric scalar; fifth measured tag parameter; for
#'     Lotek coded ID, this is the standard deviation of the second
#'     interpulse gap
#'
#' @param param6: numeric scalar; sixth measured tag parameter; for
#'     Lotek coded ID, this is the standard deviation of the third
#'     interpulse gap
#'
#' @param paramType: integer scalar; indicates the type of parameters
#'     supplied for this tag; should be a foreign key to a table with
#'     parameter type info.
#'
#' @param ts: numeric scalar; registration timestamp; typically
#'     Sys.time(), but for the time at which the registration was
#'     actually made, not just when the API was called.
#'
#' @param nomFreq: numeric scalar; nominal tag carrier frequency, in MHz
#'
#' @param dateBin: character scalar; quick and dirty approach to
#'     keeping track of tags likely to be active at a given time; this
#'     records "YYYY-Q" where Q is 1, 2, 3, or 4.  Represents the
#'     approximate quarter during which the tag is expected to be
#'     active.  Used in lieu of deployment information when that is
#'     not (yet) available.
#'
#' @param model: character scalar; Lotek tag model
#' @param ...: additional parameters to motusQuery()
#'
#' @return query results.
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusRegisterTag = function(projectID,
                            mfgID,
                            manufacturer="Lotek",
                            type="ID",
                            codeSet="Lotek6M",
                            offsetFreq,
                            period,
                            periodSD,
                            pulseLen,
                            param1,
                            param2,
                            param3,
                            param4,
                            param5,
                            param6,
                            paramType = 1,
                            ts,
                            nomFreq,
                            dateBin,
                            model,
                            ...
                            ) {
    motusQuery(MOTUS_API_REGISTER_TAG, requestType="post",
               list(
                   projectID    = projectID,
                   mfgID        = mfgID,
                   manufacturer = manufacturer,
                   type         = type,
                   codeSet      = codeSet,
                   offsetFreq   = offsetFreq,
                   period       = period,
                   periodSD     = periodSD,
                   pulseLen     = pulseLen,
                   param1       = param1,
                   param2       = param2,
                   param3       = param3,
                   param4       = param4,
                   param5       = param5,
                   param6       = param6,
                   paramType    = paramType,
                   ts           = ts,
                   nomFreq      = nomFreq,
                   dateBin      = dateBin,
                   model        = model
               ), ...)
}
