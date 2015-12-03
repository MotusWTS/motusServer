#' register a tag deployment with motus
#'
#' @param tagID Unique numeric ID assigned to the tag, provided at the
#'     time of tag registration.
#' 
#' @param status Status from one of the possible following values:
#'     pending, deploy, terminate. "pending” indicates that the
#'     deployment record isn’t ready to be finalized for deployment
#'     yet. "deploy” indicates that the deployment can be
#'     activated. "terminate” will attempt to finalize a deployment by
#'     providing an end date. Note that deployments can only be
#'     activated or terminated if all required information has been
#'     provided. Attempts to deploy or terminate an incomplete
#'     deployment will return an error. At the moment, several of the
#'     parameters can no longer be modified once a deployment is
#'     activated, and the status cannot be changed back to an earlier
#'     status (permitted sequence is pending -> deploy -> terminate,
#'     but levels can be omitted).
#'
#' @param tsStart Timestamp for start of deployment. If the tag has a
#'     deferred time lag (deferTime), this is the time at which the
#'     tag is activated, in such a way that the time when the tag is
#'     expected to be active is given by tsStart + deferTime.
#' 
#' @param tsEnd [optional] Timestamp for end of deployment. Required
#'     for status=terminate.
#'
#' @param deferTime [optional] Defer time (in seconds from
#'     tsStart). Some tags are capable of deferred activation - they
#'     don't start transmitting until some (possibly large) number of
#'     seconds after activation.
#' 
#' @param speciesID [optional] Numeric ID (integer) of the species on
#'     which the tag is being deployed. You can obtain this value by
#'     using \code{motusListSpecies()} to search by name or code.
#'
#' @param markerType [optional] Type of marker
#'     (e.g. "metal band”, "color band”)
#' 
#' @param markerNumber [optional] Marker number or descriptor
#'     (e.g. "1234-56789” or "L:Red/Blue,R:Metal 1234-56789”)
#'
#' @param lat [optional] Latitude (decimal degrees) of the deployment
#'     site. E.g. 45.123.
#'
#' @param lon [optional] Longitude (decimal degrees) of the deployment
#'     site. E.g. -60.325.
#'
#' @param elev [optional] Elevation above sea level (meters) of the
#'     deployment site. E.g. 23.
#'
#' @param ts [optional] Time at which deployment information
#'     was generated.  Defaults to time at which function is called.
#'
#' @note All timestamps must be in the form returned by \code{Sys.time()}
#' and by the \code{ymd(), ymd_hms(),..} functions from the \code[lubridate}
#' package.  i.e. they are numbers representing seconds elapsed since the start of
#' 1 Jan. 1970, GMT.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusDeployTag = 
    function(
             tagID,
             status = c("pending", "deploy", "terminate"),
             tsStart,
             tsEnd = NULL,
             deferTime = 0,
             speciesID = NA,
             markerType = NA,
             markerNumber = NA,
             lat = NA,
             lon = NA,
             elev = NA,
             ts = Sys.time()
             ) {
        
    motusQuery(MOTUS_API_DEPLOY_TAG, requestType="post",
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
                   dateBin      = dateBin
               ), ...)
}
