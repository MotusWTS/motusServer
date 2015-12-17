#' Send a query to the motus API
#'
#' @param API: one of the MOTUS_API_... constants
#'
#' @param params: named list of API-specific parameters
#'
#' @param requestType: "post" or "get"
#'
#' @param show: if TRUE, print the request to the console before submitting to motus
#'
#' @param json; if TRUE, return results as JSON-format string; otherwise, as R list
#'
#' @return the result of sending the request to the motus API.  The
#'     result is a JSON-format character scalar if \code{json} is
#'     \code{TRUE}; otherwise it is an R list with named components,
#'     extracted from the JSON return value.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusQuery = function (API, params = NULL, requestType="post", show=FALSE, json=FALSE) {
    curl = getCurlHandle()
    curlSetOpt(.opts=list(verbose=0, header=0, failonerror=0), curl=curl)
    # params is a named list of parameters which will be passed along in the JSON query

    DATE = Sys.time()
    DAY = DATE %>% format("%Y%m%d%H%M%S")

    HASH = "%s_%s_%s" %>% sprintf(MOTUS_SECRETS$serno, DAY, MOTUS_SECRETS$key) %>% digest("sha1", serialize=FALSE) %>% toupper

    ## query object for getting project list

    QUERY = c(
        list(
            serno = MOTUS_SECRETS$serno,
            hash = HASH,
            date = DAY,
            format = "jsonp",
            login = MOTUS_SECRETS$user,
            pword = MOTUS_SECRETS$passwd
            ),
        params)

    JSON = QUERY %>% toJSON (auto_unbox=TRUE, null="null")

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
