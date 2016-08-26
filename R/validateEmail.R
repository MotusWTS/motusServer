#' Verify that an incoming data email is valid, and return the name of
#' the user who sent it.
#'
#' The body and text of the email is searched for a valid token (see
#' \link{\code{getUploadToken}}) and if found, a character vector
#' giving username and email address are returned.
#'
#' @param msg the text of the email.  This is the results of running
#'     the linux utility \code{munpack} on the message.
#'
#' @return if the message contains a valid token, returns a 3-element
#'     list with these items:
#'\itemize{
#' \item username the sensorgnome.org username who owns the token
#' \item email the email address of the user
#' \item expired logical scalar; TRUE iff token the token has expired
#' }
#'
#' Otherwise, returns NULL.
#'
#' @seealso \link{\code{getUploadToken}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

validateEmail = function(msg) {
    ## a token is recognized by having a known prefix followed by 10
    ## to 100 alphanumeric characters

    tokenRE = paste0(MOTUS_UPLOAD_TOKEN_PREFIX, "(?<token>[A-Za-z0-9]{10,100})")

    res = regexpr(tokenRE, msg, perl=TRUE)

    if (length(res) == 0 || res[1] == -1) {
        ## no token found
        return(NULL)
    }

    ## token found; look it up
    s = attr(res, "capture.start")[1, "token"]
    len = attr(res, "capture.length")[1, "token"]
    tok = substr(msg, s, s + len - 1)

    x = tbl(openMotusDB(), "upload_tokens") %>% filter_(~token==tok) %>% collect

    if(nrow(x) == 0)
        return(NULL)

    now = as.numeric(Sys.time())

    return(list(username=x$username,
                email = x$email,
                expired = as.numeric(Sys.time()) > x$expiry
                ))
}
