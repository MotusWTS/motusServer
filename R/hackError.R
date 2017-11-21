#' examine the calling environments of a failed job
#'
#' @param j the top-level motus job ID one of whose subjobs failed
#'
#' @param type the type of subjob to examine.  If not specified,
#'  the first such subjob is examined.
#'
#' @param index; integer; optional.  If present, selects from multiple
#' subjobs of the same type.
#'
#' @param topLevel logical; if TRUE (the default), treat {j} as a top-level
#' job; otherwise, treat \code{j} as the job of interest, and ignore \code{type}
#' and \code{index}.
#'
#' @export

hackError = function(j, type, index, topLevel=TRUE) {
    if(missing(j))
        stop("You must specify a job number.")
    loadJobs()
    if (! isTRUE(class(j) == "Twig"))
        j = Jobs[[j]]
    if (! topLevel) {
        if (j$done >= 0)
            stop("Job ", j, " did not generate an error")
        sj = j
    } else {
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
    }
    bt <<- readRDS(file.path(MOTUS_PATH$ERRORS, sprintf("%08d.rds", sj)))
    cat("With: \n", as.character(attr(bt, "error.message")), "\n")
    cat("Traceback (also is in variable bt):\n")
    cat(paste0(sprintf("bt[[%d]]: %s", rev(seq(along=bt)), rev(names(bt))), collapse="\n\n"), "\n")
    return(invisible(NULL))
}
