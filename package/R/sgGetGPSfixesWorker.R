#' worker function to process chunks for GPS fixes
#'
#' Do not use this function directly; it is called by \code{sgGetGPSfixes}.  See \reference{sgRunStream} for documentation of parameters.
#'
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgGetGPSfixesWorker = function(bn, ts, cno, ct, u) {
    if (cno > 0) {
        ## usual case; parse stream chunk 
        u$ct[[cno]] = unlist(
            stri_extract_all_regex(
                ct,
                "^G(,[-\\.0-9E]+){4}$",
                opts_regex = list(multiline=TRUE),
                omit_no_match = TRUE
            )
        )
    } else if (cno < 0) {
        ## initialization call; -cno is number of chunks
        ## allocate a vector with slots for GPS fixes from each chunk
        u$ct = vector("list", -cno)
    } else {
        ## finally, processreturn accumulated GPS fixes
            ## extract components from GPS fix lines
        g = stri_split_regex(
            unlist(u$ct),       ## meld list of string vectors into string vector
            "[,\n]",         ## separates fields in GPS fixes from each other
            simplify = TRUE, ## convert to string array
        ) [,-1];             ## drop the leading 'G' field
        class(g) = "numeric" ## convert to numeric without dropping dims
        if (length(g) == 0)
            g = matrix(NA, 0, 4)
        return(g)
    }
}
