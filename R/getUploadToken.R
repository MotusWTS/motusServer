#' Get a random token for inclusion in data transfer emails
#'
#' To verify that incoming data are from a legitimate user, and to determine that
#' user, we ask users to fetch a token from
#'
#'   https://sensorgnome.org/Sending_Data_for_Automatic_Processing
#'
#' to include in the subject or body of their transfer email.  Tokens
#' have a fixed lifespan, defaulting to 2 weeks, and up to two
#' unexpired tokens per user can exist, so that at least one of them
#' is guaranteed to be good for at least half of the usual lifespan.
#'
#' Tokens include an 8-character preamble so that they can easily be found
#' in an email message using a regular expression.
#'
#' Tokens displayed in a web browser should be selectable by double-clicking
#' on them, since they use only alphanumeric characters from the ASCII set.
#'
#' As a side-effect, tokens are stored in the table 'upload_tokens' in
#' the motus transfer database.  Expired tokens are deleted when new
#' tokens are generated.
#'
#' @param user name of user on sensorgnome.org; default: MOTUS_ADMIN_USERNAME
#'
#' @param email email address of user on sensorgnome.org
#' default: MOTUS_ADMIN_EMAIL
#'
#' @param lifeSpan token lifespan, in days.  Default: 14.
#'
#' @param numBites number of random bits in token.  Default: 144
#' The true number of random bits will be somewhat smaller, due
#' to removal of non-alphnumeric characters '/' and '+'.
#'
#' @return a list with these items:
#' \itemize{
#' \item token character scalar giving the token, including its preamble.
#' \item expiry expiry date, as a timestamp
#' }
#'
#' @note if \code{user} is "Anonymous", return an invalid token and timestamp of 0.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getUploadToken = function(user=MOTUS_ADMIN_USERNAME, email=MOTUS_ADMIN_EMAIL, lifeSpan = 14, numBits = 144) {
    if (user=="Anonymous")
        return(list(token="INVALID; YOU MUST BE LOGGED IN", expiry=structure(0, class=c("POSIXt", "POSIXct"))))

    openMotusDB() ## ensure MotusDB exists

    ## check for existing tokens for this user; if there's one still good
    ## for at least 1/2 a lifetime, return it

    now = as.numeric(Sys.time())

    old = MotusDB("select token, expiry from upload_tokens where username=%s and email=%s and expiry - %f >= %f order by expiry desc limit 1",
                  user,
                  email,
                  now,
                  lifeSpan / 2 * 24 * 3600
                  )

    if (nrow(old) == 1) {
        token = old$token
        expiry = old$expiry
    } else {

        ## delete expired tokens

        MotusDB("delete from upload_tokens where username=%s and email=%s and expiry <= %f", user, email, now)

        ## generate new token with lots of extra bits so we can remove non-alphanum chars

        repeat {
            token = base64_encode(rand_bytes(2 * numBits / 8))
            token = gsub('[+/]', '', token, perl=TRUE)
            if (nchar(token) >= ceiling(numBits / 6))
                break
        }
        token = substr(token, 1, ceiling(numBits / 6))
        expiry = now + lifeSpan * 24 * 3600

        MotusDB("insert into upload_tokens (username, email, token, expiry) values (%s, %s, %s, %f)",
              user,
              email,
              token,
              expiry)
    }
    return(list(token = paste0(MOTUS_UPLOAD_TOKEN_PREFIX, token), expiry=structure(expiry, class=c("POSIXt", "POSIXct"))))
}
