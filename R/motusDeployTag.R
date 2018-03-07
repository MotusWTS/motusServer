#' register a tag deployment with motus
#'
#' @param tagID Unique numeric ID assigned to the tag, provided at the
#'     time of tag registration.
#'
#' @param projectID numeric ID of motus project for which this tag is
#'     being deployed.
#'
#' @param status Status from one of the possible following values:
#'     pending, deploy, terminate. "pending" indicates that the
#'     deployment record isn’t ready to be finalized for deployment
#'     yet. "deploy" indicates that the deployment can be
#'     activated. "terminate" will attempt to finalize a deployment by
#'     providing an end date. Note that deployments can only be
#'     activated or terminated if all required information has been
#'     provided. Attempts to deploy or terminate an incomplete
#'     deployment will return an error. At the moment, several of the
#'     parameters can no longer be modified once a deployment is
#'     activated, and the status cannot be changed back to an earlier
#'     status (permitted sequence is pending -> deploy -> terminate,
#'     but levels can be omitted).
#'
#' @param tsStart [optional] Timestamp for start of deployment. If the tag has a
#'     deferred time lag (deferTime), this is the time at which the
#'     tag is activated, so that the time when the tag is
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
#'     Alternatively, this can be a character scalar giving the species
#'     4-lettercode; e.g. "SESA"
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
#' @param comments [optional] deployment-related comment
#'
#' @param properties [optional] list or vector; additional properties
#'     of the deployment or the organism on which the tag is deployed.
#'     This will be formatted as a JSON string then inserted into the
#'     \code{properties} field of the database.  FIXME: for now,
#'     it goes into the comments field.
#'
#' @param ts [optional] Time at which deployment information
#'     was generated.  Defaults to time at which function is called.
#'
#' @note All timestamps must be in the form returned by \code{Sys.time()}
#' and by the \code{ymd(), ymd_hms(),..} functions from the \code{lubridate}
#' package.  i.e. they are numbers representing seconds elapsed since the start of
#' 1 Jan. 1970, GMT.
#'
#' @note For timestamps in the future, this function uses the \code{tsAnticipatedStart} parameter
#' to the motus /tags/deploy API.  For timestamps in the past, it uses \code{tsStart}.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusDeployTag =
    function(
             tagID,
             projectID,
             status       = c("pending", "deploy", "terminate"),
             tsStart      = NULL,
             tsEnd        = NULL,
             deferTime    = 0,
             speciesID    = NULL,
             markerType   = NULL,
             markerNumber = NULL,
             lat          = NULL,
             lon          = NULL,
             elev         = NULL,
             comments     = NULL,
             properties   = NULL,
             ts           = as.numeric(Sys.time())
             ) {

        ## convert NA or "" to null for the API
        for (n in c("lat", "lon", "elev", "tsStart", "tsEnd")) {
            v = get(n)
            if (isTRUE(! is.null(v) && (is.na(v) || (is.character(v) && "" == v))))
                assign(n, NULL)
        }

        ## convert non-NULL to numeric
        for (n in c("tsStart", "tsEnd")) {
            v = get(n)
            if (isTRUE(! is.null(v)))
                assign(n, as.numeric(v))
        }

        status = match.arg(status)
        if (! is.null(properties))
            properties = c(list(), properties, comments=comments)

        if (is.character(speciesID)) {
            newSpeciesID = motusListSpecies(speciesID, qlang="CD")$id
            if (is.null(speciesID))
                stop("Unknown species:", speciesID)
            if (length(newSpeciesID) > 1)
                stop("Multiple species matching:", speciesID)
            speciesID = newSpeciesID
        }

        motusQuery(
            MOTUS_API_DEPLOY_TAG,
            requestType="post",
            list(
                tagID        = tagID,
                projectID    = projectID,
                status       = status,
                tsStart      = tsStart,
                tsEnd        = tsEnd,
                deferTime    = deferTime,
                speciesID    = speciesID,
                markerType   = markerType,
                markerNumber = markerNumber,
                lat          = lat,
                lon          = lon,
                elev         = elev,
                ## FIXME; when API works, use the following instead
                ## comments     = comments,
                ## properties   = properties,
                comments     = if(length(properties) == 0) NULL else as.character(toJSON(properties, auto_unbox=TRUE)),
                ts           = ts
            )
        )
    }
