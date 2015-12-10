#' Constants for the motus package.
#'
#' API entry points:
#' 
MOTUS_API_ENTRY_POINTS = 'http://motus-wts.org/data/api/entrypoints.jsp'
MOTUS_API_REGISTER_TAG = 'http://motus-wts.org/data/api/v1.0/registertag.jsp'
MOTUS_API_DEPLOY_TAG = 'http://motus-wts.org/data/api/v1.0/deploytag.jsp'
MOTUS_API_REGISTER_PROJECT = 'http://motus-wts.org/data/api/v1.0/registerproject.jsp'
MOTUS_API_LIST_PROJECTS = 'http://motus-wts.org/data/api/v1.0/listprojects.jsp'
MOTUS_API_RECEIVER_STATUS = 'http://motus-wts.org/data/api/v1.0/listreceiverstatus.jsp'
MOTUS_API_LIST_TAGS = 'http://motus-wts.org/data/api/v1.0/listtags.jsp'
MOTUS_API_LIST_SENSORS = 'http://motus-wts.org/data/api/v1.0/listsensors.jsp'
MOTUS_API_LIST_SPECIES = 'http://motus-wts.org/data/api/v1.0/listspecies.jsp'
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

MOTUS_FLOAT_REGEXP = sprintf("((%s):-?[0-9]+)([,}])",
                             paste(sprintf("\"%s\"", MOTUS_FLOAT_FIELDS), collapse="|"))
