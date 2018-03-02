#' Send a query to the motus API
#'
#' @param API one of the MOTUS_API_... constants
#'
#' @param params named list of API-specific parameters
#'
#' @param requestType "post" or "get"
#'
#' @param show if TRUE, print the request to the console before submitting to motus
#'
#' @param json if TRUE, return results as JSON-format string; otherwise, as R list
#'
#' @param serno serial number of receiver from which request is being
#'     sent; if NULL, the default, uses MOTUS_SECRETS$serno.
#'
#' @param masterKey if NULL (the default), use key from the
#'     MOTUS_SECRETS object.  Otherwise, \code{masterKey} is the name
#'     of a file to read the secret key from.
#'
#' @return the result of sending the request to the motus API.  The
#'     result is a JSON-format character scalar if \code{json} is
#'     \code{TRUE}; otherwise it is an R list with named components,
#'     extracted from the JSON return value.
#'     If the query returns with a status code of >= 400, this function calls stop(X) where
#'     X is the (typically JSON-encoded) body of the reply.
#'
#' @note all queries and return values are logged in the file "motus_query_log.txt"
#' in the user's home directory.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusQuery = function (API, params = NULL, requestType="post", show=FALSE, json=FALSE, serno=NULL, masterKey=NULL) {
    # params is a named list of parameters which will be passed along in the JSON query

    DATE = Sys.time()
    DAY = DATE %>% format("%Y%m%d%H%M%S")

    ## for a few
    if (is.null(masterKey))
        KEY = MOTUS_SECRETS$key
    else
        KEY = readLines(masterKey)

    if (is.null(serno))
        serno = MOTUS_SECRETS$serno

    HASH = "%s_%s_%s" %>% sprintf(toupper(serno), DAY, KEY) %>% digest("sha1", serialize=FALSE) %>% toupper

    ## query object for getting project list

    QUERY = c(
        list(
            serno = serno,
            hash = HASH,
            date = DAY,
            fmt = "json",
            login = MOTUS_SECRETS$user,
            pword = MOTUS_SECRETS$passwd
            ),
        params)

    JSON = QUERY %>% toJSON (auto_unbox=TRUE, null="null")

    ## add ".0" to the end of any integer-valued floating point fields
    JSON = gsub(MOTUS_FLOAT_REGEX, "\\1.0\\3", JSON, perl=TRUE)

    if(show)
        cat(JSON, "\n")

    log = file("~/motus_query_log.txt", "a")
    on.exit(close(log))
    cat(format(Sys.time()), ",", requestType, ",", API, ",", JSON, "\n", file=log)
    retries = 0
    maxRetries = 5
    while(retries <= maxRetries) {
        tryCatch({
            if (requestType == "post")
                r = httr::POST(API, body=list(json=JSON), encode="form")
            else
                r = httr::GET(API, query=list(json=JSON))
            break
        }, error=function(e) {
            retries <- retries + 1
            if (retries > maxRetries) {
                cat("ERROR: ", as.character(e), "\n", file=log)
                stop ("MotusQuery failed with error; ", as.character(e))
            }
            if (any(grepl("TLS packet with unexpected length", as.character(e)))) {
                Sys.sleep(5)
            }
        })
    }
    rv = httr::content(r, "text")

    if (httr::status_code(r) >= 300)
        stop(rv)

    if (! json) {
        ## we use jsonlite::fromJSON(rv) rather than httr::content(rv) because the
        ## latter doesn't structure its output as a data.frame

        rv = fromJSON(rv)
        if (! is.null(rv$data))
            rv = rv$data
    }
    return(rv)
}
