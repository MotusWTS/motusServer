#' load secrets for motus web API
#'
#' @param f filename: path to json-formatted file of secrets,
#' with these items:
#' \enumerate{
#'   \item key: API key; a secret
#'   \item user: username at motus-wts.org
#'   \item passwd: password at motus-wts.org
#'   \item serno: serial number of a sensorgnome
#' }
#'
#' @param quiet if TRUE, return silently on failure; otherwise,
#' report errors.
#' 
#' @return TRUE if secrets were successfully loaded.
#' 
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusLoadSecrets = function(f, quiet=FALSE) {
    if (missing(f)) {
        f = system.file("motusSecrets.json", package="motus")
        if (! file.exists(f)) {
            if (quiet)
                return(FALSE)
            stop("The package file motusSecrets.json is not installed.
You will not be able to use most motus functions without the credentials
provided in this file.

After receiving the file, use the function motusLoadSecrets(f) to load
the secrets for a session, and saveSecrets() to store them permanently.")
        }
    }
    MOTUS_SECRETS <<- f %>% readLines %>% paste(collapse="\n") %>% fromJSON
    return (TRUE)
}

