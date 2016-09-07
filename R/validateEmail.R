#' Verify that an incoming data email is valid, and return the name of
#' the user who sent it.
#'
#' The body and text of the email is searched for a valid token (see
#' \link{\code{getUploadToken}}) and if found, the username and email
#' address are returned.
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

    res = regexPieces(MOTUS_UPLOAD_TOKEN_REGEXP, msg)[[1]]

    if (length(res) == 0) {
        ## no token found
        return(NULL)
    }

    ## look up the first token found

    tok = res[1]

    x = tbl(openMotusDB(), "upload_tokens") %>% filter_(~token==tok) %>% collect

    if(nrow(x) == 0)
        return(NULL)

    now = as.numeric(Sys.time())

    return(list(username = x$username,
                email    = x$email,
                expired  = as.numeric(Sys.time()) > x$expiry
                ))
}
