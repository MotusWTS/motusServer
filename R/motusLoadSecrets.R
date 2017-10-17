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
#' This defaults to the file \code{motusSecrets.json} installed
#' with this package.
#'
#' @param quiet if TRUE, return silently on failure; otherwise,
#' report errors.
#'
#' @return TRUE if secrets were successfully loaded.
#'
#' @note This function also loads a shared secret for apache's mod-auth-tkt
#' ticket authentication module.  This is parsed from the file
#' whose path is MOTUS_MODAUTHTKT_SECRET_KEYFILE, defined in motusConstants.R
#'
#' @export
#'
#' @importFrom jsonlite fromJSON
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusLoadSecrets = function(f = system.file("motusSecrets.json", package="motusServer"), quiet=FALSE) {
    if (! file.exists(f)) {
        if (quiet)
            return(FALSE)
        stop("The package file motusSecrets.json is not installed.
You will not be able to use most motus functions without the credentials
provided in this file.

After receiving the file, use the function motusLoadSecrets(f) to load
the secrets for a session, and saveSecrets() to store them permanently.")
    }
    MOTUS_SECRETS <<- fromJSON(textFileContents(f))

    ## parse out the 'TKTAuthSecret' field from the apache config file
    tktsecret = grep("TKTAuthSecret", readLines(MOTUS_MODAUTHTKT_SECRET_KEYFILE), val=TRUE)

    MOTUS_SECRETS$mod_auth_tkt <<- charToRaw(read.table(textConnection(tktsecret), as.is=TRUE)[[2]])

    return (TRUE)
}
