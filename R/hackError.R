#' examine the calling environments of a failed job
#'
#' @param j the top-level motus job ID one of whose subjobs failed
#'
#' @param type the type of subjob to examine.  If not specified,
#'  the first such subjob is examined.
#'
#' @export

hackError = function(j, type, index) {
    if(missing(j))
        stop("You must specify a job number.")
    loadJobs()
    if (! isTRUE(class(j) == "Twig"))
        j = Jobs[[j]]
    sjs = progeny(j)
    sjs = sjs[sjs$done < 0]
    if (length(sjs) == 0)
        stop("No subjobs failed")
    if (missing(type)) {
        cat("These failed: \n",
            paste0(paste0(seq(along=sjs), ". ", as.numeric(sjs), ": ", sjs$type), collapse="\n"),
            "\n")
        if (missing(index)) {
            if (length(sjs) == 1)
                index = 1
        }
        while (missing(index) || ! index %in% seq_len(sjs)) {
            cat("Enter index (1...) of which subjob to examine: ")
            index = as.integer(readLines(n=1))
        }
        sj = sjs[index]
    } else {
        sj = sjs[which(tolower(sjs$type) == tolower(type))][1]
        if (length(sj) == 0)
            stop("No subjobs of that type failed")
    }
    bt <<- readRDS(file.path(MOTUS_PATH$ERRORS, sprintf("%08d.rds", sj)))
    cat("With: \n", as.character(attr(bt, "error.message")), "\n")
    cat("Traceback (also is in variable bt):\n")
    cat(paste0(sprintf("bt[[%d]]: %s", rev(seq(along=bt)), rev(names(bt))), collapse="\n\n"), "\n")
    return(invisible(NULL))
}
