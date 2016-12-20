#' return the process group ID for the R session
#'
#' This process group ID (PGID) is used as the owner token for
#' locks acquired on symbols, e.g.  It is known by the shell
#' scripts which launch the email, status, and process servers,
#' and is used by those scripts to remove locks if those
#' servers die.
#'
#' @return integer scalar giving the process group ID.
#'
#'
#' @seealso \code{\link{lockSymbol}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getPGID = function() {
    stat = readLines(file.path("/proc", Sys.getpid(), "stat"), n=1)
    ## drop the process name (surrounded in parens) before trying to parse
    ## out the pgid
    stat = sub(".*\\) ", "", stat, perl=TRUE)
    return(as.integer(strsplit(stat, " ", fixed=TRUE)[[1]][3]))
}
