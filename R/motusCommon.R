## motusCommon.R
##
## - definitions required by motus API functions
##

require(dplyr)
library(digest)
library(jsonlite)
library(RCurl)
library(RSQLite)
library(lubridate)

MOTUS_API_USER = 'john'
## get the motus API key and password for account john 
motusSecrets = system("sudo cat ~/.secrets/motusAPISecrets", intern=TRUE) %>% fromJSON()

MOTUS_API_ENTRY_POINTS = 'http://motus-wts.org/data/api/entrypoints.jsp'
MOTUS_API_REGISTER_TAG = 'http://motus-wts.org/data/api/v1.0/registertag.jsp'
MOTUS_API_LIST_PROJECTS = 'http://motus-wts.org/data/api/v1.0/listprojects.jsp'
MOTUS_API_RECEIVER_STATUS = 'http://motus-wts.org/data/api/v1.0/listreceiverstatus.jsp'
MOTUS_API_LIST_TAGS = 'http://motus-wts.org/data/api/v1.0/listtags.jsp'
MOTUS_API_LIST_SENSORS = 'http://motus-wts.org/data/api/v1.0/listsensors.jsp'
MOTUS_API_SEARCH_TAGS = 'http://motus-wts.org/data/api/v1.0/searchtags.jsp'
MOTUS_API_DEBUG = 'http://motus-wts.org/data/api/v1.0/debug.jsp'

# a list of field names which must be formatted as floats so that
# the motus API recognizes them correctly.  This means that if they
# happen to have integer values, a ".0" must be appended to the JSON
# field value.  We do this before sending any query.

MOTUS_FLOAT_FIELDS = c("tsStart", "tsEnd", "regStart", "regEnd",
"offsetFreq", "period", "periodSD", "pulseLen", "param1", "param2",
"param3", "param4", "param5", "param6", "ts", "nomFreq")

## a regular expression for replacing values that need to be floats
## Note: only works for named scalar parameters; i.e. "XXXXX":00000

MOTUS_FLOAT_REGEXP = paste("((", paste(sprintf("\"%s\"", MOTUS_FLOAT_FIELDS), collapse="|"), ")", ":-?[0-9]+)([,}])", sep="")

MOTUS_API_SERNO = 'SG-0815BBBK1352'  ## for no particular reason, we're using this one

motusQuery = function (API, params = NULL, requestType="post", show=FALSE, json=FALSE) {
    curl = getCurlHandle()
    curlSetOpt(.opts=list(verbose=0, header=0, failonerror=0), curl=curl)
    # params is a named list of parameters which will be passed along in the JSON query
    
    DATE = Sys.time()
    DAY = DATE %>% format("%Y%m%d%H%M%S")

    HASH = "%s_%s_%s" %>% sprintf(MOTUS_API_SERNO, DAY, motusSecrets$API_KEY) %>% digest("sha1", serialize=FALSE) %>% toupper

    ## query object for getting project list

    QUERY = c(
        list(
            serno = MOTUS_API_SERNO,
            hash = HASH,
            date = DAY,
            format = "jsonp",
            login = MOTUS_API_USER,
            pword = motusSecrets$passwd
            ),
        params)
    
    JSON = QUERY %>% toJSON (auto_unbox=TRUE)

    ## add ".0" to the end of any integer-valued floating point fields
    JSON = gsub(MOTUS_FLOAT_REGEXP, "\\1.0\\3", JSON, perl=TRUE)
    
    if(show)
        cat(JSON, "\n")

    tryCatch({
        if (requestType == "post")
            RESP = postForm(API, json=JSON, style="post", curl=curl)
        else
            RESP = getForm(API, json=JSON, curl=curl)
        if (json)
            return (RESP)
        return(fromJSON(RESP) $ data)
    }, error=function(e) {
        stop (capture.output(e))
    })
}

## short cuts

motusListProjects = function(type="both", ...) {
    # type can be "tag", "sensor", or "both"
    motusQuery(MOTUS_API_LIST_PROJECTS, requestType="get",
               list(
                   type = type
               ), ...)
}

motusListSensors = function(projectID = NULL, year = NULL, serialNo=NULL, macAddress=NULL...) {
    motusQuery(MOTUS_API_LIST_SENSORS, requestType="get",
               list(
                   projectID  = projectID,
                   year       = year,
                   serialNo   = serialNo,
                   macAddress = macAddress
               ), ...)
}

motusListTags = function(projectID, year = NULL, mfgID = NULL, ...) {
    motusQuery(MOTUS_API_LIST_TAGS, requestType="get",
               list(
                   projectID = projectID,
                   year      = year,
                   mfgID     = mfgID
               ), ...)
}

motusSearchTags = function(projectID = NULL, tsStart = NULL, tsEnd = NULL, regStart = NULL, regEnd = NULL, mfgID = NULL, ...) {
    motusQuery(MOTUS_API_SEARCH_TAGS, requestType="get",
               list(
                   projectID = projectID,
                   tsStart   = FLOAT(tsStart),  ## NB: force these to look like reals, not integers
                   tsEnd     = FLOAT(tsEnd),
                   regStart  = FLOAT(regStart),
                   regEnd    = FLOAT(regEnd),
                   mfgID     = mfgID
               ), ...)
}

motusRegisterTag = function(projectID,
                            mfgID,
                            manufacturer="Lotek",
                            type="ID",
                            codeSet="Lotek-4",
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
                   dateBin      = dateBin                   
               ), ...)
}


proccessRawFiles = function(YEAR, PROJ, SITE) {
    # run data from a site through the tag finder, generating
    # batch tables for motus.

    # for each (receiver, bootnum) pair at the site:

    # 0. determine the datespan for the data from that receiver, bootnum
    # 1. query motus to get the motusID for the receiver
    # 2. query motus to get the list of tags to loook for, given the datespan
    # 3. run the tag finder
    # 4. generate batches to put into the motus transfer tables

}
