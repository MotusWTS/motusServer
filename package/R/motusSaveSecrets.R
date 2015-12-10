#' save secrets for motus web API in default location
#'
#' If the variable MOTUS_SECRETS is not NULL, its contents are stored
#' in JSON format in the package file motusSecrets.json, from where
#' they will be automatically read when the \code{motus} package is
#' loaded.
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusSaveSecrets = function() {
    if (is.null(MOTUS_SECRETS))
        stop("No Motus API secrets have been loaded.\nUse motusLoadSecrets(FILE)")

    f = file.path(system.file(package="motus"), "motusSecrets.json")
    MOTUS_SECRETS %>% toJSON %>% writeLines(f)
}

