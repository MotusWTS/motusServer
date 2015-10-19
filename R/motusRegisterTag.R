#!/usr/bin/Rscript --slave

._(` (

motusRegisterTag.R

register a tag with motus-wts.org

Call this script as so:

  motusRegisterTag.R YEAR PROJCODE TAGID

where:

  YEAR: 4 digit year of tag's registration with sensorgnome.org

  PROJCODE: character project code as used on sensorgnome.org or integer
           motus project ID.  A sensorgnome.org project directory will be
           mapped to the appropriate motus project ID via the
           projectMap table in the sg_motus.sqlite database.  If no motus
           ID is found, a list of all motus projects is printed.

  TAGID: tag ID as found in one of the /SG/YYYY_tags.csv files

examples:

  /SG/code/motusRegisterTag.R 2014 taylor 503

._(` )

ARGS = commandArgs(TRUE)

if (length(ARGS) < 3) {
    ._SHOW_INFO()
    quit(save="no")
}

YEAR    = as.integer(ARGS[1])
PROJCODE = ARGS[2]
TAGID   = ARGS[3]

require(dplyr)
library(digest)
library(rjson)
library(RCurl)
library(RSQLite)
library(lubridate)

curl = getCurlHandle()
curlSetOpt(.opts=list(verbose=1, header=1, failonerror=0), curl=curl)
motusAPIPasswd = system("sudo cat ~/.secrets/motusAPIPasswd", intern=TRUE)
motusCon = dbConnect(RSQLite::SQLite(), "/SG/motus_sg.sqlite")
sgCon = dbConnect(RSQLite::SQLite(), sprintf("/SG/%d_tags.sqlite", YEAR))

sql = function(con, query, ...) {
    return (dbGetQuery(con, sprintf(query, ...)))
}

FLOAT = function(x) {
    ## ensure that all numbers in x have additional digits after the decimal point
    ## so that when output via toJSON, they don't look like integers to silly
    ## JSON readers that interpret lack of decimal point as meaning "integer".
    ## This is required by the Motus API.

    ints = which(x == trunc(x))

    ## add 1e-6 to each 'integer'.
    x[ints] = x[ints] + 1e-6

    return(x)
}

API_REGISTER_TAG = 'http://motus-wts.org/data/api/v1.0/registertag.jsp'
API_LIST_PROJECTS = 'http://motus-wts.org/data/api/v1.0/listprojects.jsp'
API_ENTRY_POINTS = 'http://motus-wts.org/data/api/entrypoints.jsp'
API_RECEIVER_STATUS = 'http://motus-wts.org/data/api/v1.0/listreceiverstatus.jsp'
API_LIST_TAGS = 'http://motus-wts.org/data/api/v1.0/listtags.jsp'
API_LIST_SENSORS = 'http://motus-wts.org/data/api/v1.0/listsensors.jsp'
API_SEARCH_TAGS = 'http://motus-wts.org/data/api/v1.0/searchtags.jsp'


KEY = '1C5CED2F219146033A078FC3F985AAACD1C18E00'
SERNO = 'SG-0815BBBK1352'
DATE = Sys.time()
DAY = DATE %>% format("%Y%m%d%H%M%S")

HASH = "%s_%s_%s" %>% sprintf(SERNO, DAY, KEY) %>% digest("sha1", serialize=FALSE) %>% toupper

## query object for getting project list

QUERY = list(
    serno = SERNO,
    hash = HASH,
    date = DAY,
    format = "jsonp",
    login = "john",
    pword = motusAPIPasswd
    )

JSON = QUERY %>% toJSON

##print(getForm(API_ENTRYPOINTS, json=JSON) %>% fromJSON)
##print(getForm(API_RECEIVERSTATUS, json=JSON) %>% fromJSON)


## get motus ID for project 
projInfo = sql(motusCon, "select * from projectMap where projCode='%s' and year=%d limit 1", PROJCODE, YEAR)

if (nrow(projInfo) == 0)
    stop("Project code ", PROJCODE, " is not known")

if (! is.finite(projInfo$motusID) || projInfo$motusID == 0) {
##     ## get project list from motus
##     motusProjects = getForm(API_LIST_PROJECTS, json=JSON) %>% fromJSON
##     msg = paste(lapply(motusProjects$data, function(x) sprintf("Motus Project %d '%s'\n", x$id, x$name)), collapse="")
    stop("Project ", projInfo$projCode, " does not have a MotusID")
}

## test API_LIST_SENSORS
##QUERY = c(QUERY, projectID = projInfo$motusID)
## QUERY = c(QUERY, projectID = 32)
## JSON = QUERY %>% toJSON
## print(getForm(API_LIST_SENSORS, json=JSON) %>% fromJSON)
## q()

## test API_LIST_TAGS
## QUERY = c(QUERY, projectID = projInfo$motusID)
## JSON = QUERY %>% toJSON
## print(getForm(API_LIST_TAGS, json=JSON) %>% fromJSON)
## q()

## test API_SEARCH_TAGS
## QUERY = c(QUERY, regStart = FLOAT(as.numeric(ymd("2015-01-01"))), regEnd = FLOAT(as.numeric(ymd("2015-03-31"))))
## JSON = QUERY %>% toJSON

## xx = getForm(API_SEARCH_TAGS, json=JSON) %>% fromJSON
## saveRDS(xx, "/tmp/resp.rds")
## cat("Saved tag search results to /tmp/resp.rds")

## q()


## get tag info from SG database

t = sql(sgCon, "select * from tags where proj='%s' and id=%s", PROJCODE, TAGID)

if (nrow(t) == 0)
    stop("Tag ", TAGID, " from project ", PROJCODE, " in year ", YEAR, " was not found.")

regts = FLOAT(file.info(t$filename)$ctime)

if (is.na(t$bi_sd))
    t$bi_sd=-1

QUERY = QUERY %>% c(., list (
    
    projectID = projInfo$motusID,
##    tagID = 0,  ## unique motus value, only non-zero for 'continue registration' API
    mfgID = TAGID,
    manufacturer = "Lotek",
    type = "ID",
    codeSet = if (PROJCODE=="Helgoland") "Lotek-3" else "Lotek-4",
    offsetFreq = FLOAT(t$dfreq + (t$fcdFreq - t$tagFreq) * 1000),
    period = FLOAT(t$bi),
    periodSD = FLOAT(t$bi_sd),
    pulseLen = FLOAT(2.5),
    param1 = FLOAT(t$g1),
    param2 = FLOAT(t$g2),
    param3 = FLOAT(t$g3),
    param4 = FLOAT(t$g1_sd),
    param5 = FLOAT(t$g2_sd),
    param6 = FLOAT(t$g3_sd),
    paramType = 1,
    ts = regts,
    nomFreq = FLOAT(t$tagFreq),
    dateBin = sprintf("%4d-%1d", year(regts), ceiling(month(regts)/3))
    ))

JSON = QUERY %>% toJSON

cat(JSON, "\n")

tryCatch({
    RESP = postForm(API_REGISTER_TAG, json=JSON, style="post", curl=curl) %>% fromJSON
    print(RESP)
}, error=function(e) {
    cat("Error:\n")
    print(capture.output(e))
})



