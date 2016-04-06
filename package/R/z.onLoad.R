.onLoad = function(...) {
    options(digits=14)
    if (motusLoadSecrets(quiet=TRUE))
        return()
    MOTUS_SECRETS <<- new.env(emptyenv())
    makeActiveBinding(
        'key',
        function(x) {
            stop(call. = FALSE,
                "This function requires motus credentials.\nUse motusLoadSecrets() to load them.")
        }, MOTUS_SECRETS
    )
}
