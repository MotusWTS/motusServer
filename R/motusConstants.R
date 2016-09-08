#' Constants for the motus package.
#'
#' API entry points:
#'

MOTUS_API_ENTRY_POINTS          = 'http://motus.org/data/api/entrypoints.jsp'
MOTUS_API_REGISTER_TAG          = 'http://motus.org/data/api/v1.0/registertag.jsp'
MOTUS_API_DEPLOY_TAG            = 'http://motus.org/data/api/v1.0/deploytag.jsp'
MOTUS_API_REGISTER_PROJECT      = 'http://motus.org/data/api/v1.0/registerproject.jsp'
MOTUS_API_REGISTER_RECEIVER     = 'http://motus.org/data/api/v1.0/registersensor.jsp'
MOTUS_API_LIST_PROJECTS         = 'http://motus.org/data/api/v1.0/listprojects.jsp'
MOTUS_API_RECEIVER_STATUS       = 'http://motus.org/data/api/v1.0/listreceiverstatus.jsp'
MOTUS_API_LIST_TAGS             = 'http://motus.org/data/api/v1.0/listtags.jsp'
MOTUS_API_LIST_SENSORS          = 'http://motus.org/data/api/v1.0/listsensors.jsp'
MOTUS_API_LIST_SENSOR_DEPS      = 'http://motus.org/data/api/v1.0/listsensordeployments.jsp'
MOTUS_API_LIST_SPECIES          = 'http://motus.org/data/api/v1.0/listspecies.jsp'
MOTUS_API_SEARCH_TAGS           = 'http://motus.org/data/api/v1.0/searchtags.jsp'
MOTUS_API_DEBUG                 = 'http://motus.org/data/api/v1.0/debug.jsp'
MOTUS_API_DELETE_TAG_DEPLOYMENT = 'http://motus.org/data/api/v1.0/deletetagdeployment.jsp'

# a list of field names which must be formatted as floats so that
# the motus API recognizes them correctly.  This means that if they
# happen to have integer values, a ".0" must be appended to the JSON
# field value.  We do this before sending any query.  This is
# only required due to motus using a crappy JSON parser.

MOTUS_FLOAT_FIELDS = c("tsStart", "tsEnd", "regStart", "regEnd",
"offsetFreq", "period", "periodSD", "pulseLen", "param1", "param2",
"param3", "param4", "param5", "param6", "ts", "nomFreq", "deferTime", "lat", "lon", "elev")

## a regular expression for replacing values that need to be floats
## Note: only works for named scalar parameters; i.e. "XXXXX":00000

MOTUS_FLOAT_REGEX = sprintf("((%s):-?[0-9]+)([,}])",
                             paste(sprintf("\"%s\"", MOTUS_FLOAT_FIELDS), collapse="|"))

## a pre-amble that gets pasted before upload tokens so they can easily be found in emails

MOTUS_UPLOAD_TOKEN_PREFIX = "3cQejZ7j"

## the regular expression for recognizing an authorization token in an email

MOTUS_UPLOAD_TOKEN_REGEX = paste0(MOTUS_UPLOAD_TOKEN_PREFIX, "(?<token>[A-Za-z0-9]{10,100})")

## when an incoming email is stored, the filename has this format: (see inst/scripts/incomingEmail.sh )

MOTUS_EMAIL_FILE_REGEX = "msg_[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}\\.[0-9]{6}.txt"

## a downloadable link file has a filename of this form:
MOTUS_DOWNLOADABLE_LINK_FILE_REGEX = "url_[[:alphanum:]]*.txt"

## when an outgoing email is stored, the filename has this format:

MOTUS_OUTGOING_MSG_FILENAME_FMT = "out_%Y-%m-%dT%H-%M-%OS6.txt.bz2"

## format of date/time in logfiles

MOTUS_LOG_TIME_FORMAT = "%Y-%m-%dT%H-%M-%OS6"

## "From" address for outgoing emails

MOTUS_OUTGOING_EMAIL_ADDRESS = "info@sensorgnome.org"

## filesystem layout; dirs end in "/"

MOTUS_PATH = list(
    ROOT    = "/sgm",
    BIN     = "/sgm/bin",             ## executable scripts
    CACHE   = "/sgm/cache",           ## recent results of large queries from motus.org
    QUEUE   = "/sgm/incoming",        ## files / dirs moved here are processed by server()
    EMAILS  = "/sgm/emails",          ## saved copies of valid data-transfer emails
    LOGS    = "/sgm/logs",            ## processing logs
    MANUAL  = "/sgm/manual",          ## folders needing manual attention
    MOTR    = "/sgm/motr",            ## links to receiver DBs by motus ID
    OUTBOX  = "/sgm/outbox",          ## copies of all sent emails
    PLOTS   = "/sgm/plots",           ## generated plots
    PUB     = "/sgm/pub",             ## web-visible public content
    RECV    = "/sgm/recv",            ## receiver databases
    RECVLOG = "/sgm/recvlog",         ## logfiles from receivers
    REFS    = "/sgm/refs",            ## links to receiver DBs by year, projCode, siteCode
    SPAM    = "/sgm/spam",            ## saved invalid emails
    TAGS    = "/sgm/tags",            ## ??
    TMP     = "/sgm/tmp"              ## temporary storage persistent across reboots
)

## main logfile name
MOTUS_MAINLOG_NAME = "mainlog.txt"

## default file mode for new files, folders:
MOTUS_DEFAULT_FILEMODE = "0750"

## compressed archives we can handle
MOTUS_ARCHIVE_SUFFIXES = c(
    "zip",
    "7z",
    "rar"
)

MOTUS_ARCHIVE_REGEX = paste0("(?i)\\.(?<suffix>",
                             paste(MOTUS_ARCHIVE_SUFFIXES, collapse="|"),
                             ")$")

## allowed file suffixes for emailed data files:

MOTUS_FILE_ATTACHMENT_SUFFIXES = c(
    MOTUS_ARCHIVE_SUFFIXES,
    "txt",                 ## Some users directly attach raw sensorgome files
    "txt\\.gz",            ## to an email.
    "dta"                  ## File from lotek receiver
    )

## regex to match filenames against for checking suffix

MOTUS_FILE_ATTACHMENT_REGEX = paste0("(?i)\\.(?<suffix>",
                                     paste(MOTUS_FILE_ATTACHMENT_SUFFIXES, collapse="|"),
                                     ")$")


## regex to match receiver serial numbers (adapted from sgFilenameRegex, which differs
## in not using the 'SG-' prefix).

MOTUS_SG_SERNO_REGEX = "(?<serno>SG-[0-9A-Z]{4}(?:RPi2|BBBK|BB)[0-9A-Z]{4,6}(_[0-9])?)"

## deprecated: path to db for looking up proj, site by serial number
## this for processing data the old sensorgnome way, not the new
## motus way.

MOTUS_RECV_SERNO_DB = "/SG/receiver_serno.sqlite"
