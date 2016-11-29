#' Process a new batch of files from a Lotek receiver.
#'
#' Merge the files into the appropriate receiver databases, and run the tag
#' finder on each receiver.
#'
#' @param files either a character vector of full paths to files, or
#'     the full path to a directory, which will be searched
#'     recursively for raw sensorgnome data files.
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{MOTUS_PATH$RECV}
#'
#' @param ... additional parameters to the tag finder; see \link{\code{ltFindTags}}
#'
#' @return the data.frame returned by \code{ltMergeFiles(files, dbdir)}.
#'
#' @export
#'
#' @seealso \code{ltMergeFiles} and \code{ltFindTags}, which this function calls.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

ltRunNewFiles = function(files, dbdir = MOTUS_PATH$RECV, ...) {
    rv = ltMergeFiles(files, dbdir)
    info = rv %>% arrange(serno) %>% group_by(serno)

    ## a function to process files from each receiver

    runReceiver = function(f) {
        ## nothing to do if no new files to use

        if (! any(f$dataNew))
            return(0)

        src = getRecvSrc(f$serno[1], dbdir)
        ltFindTags(src, getMotusMetaDB(), ...)
        closeRecvSrc(src)
    }

    info %>% do (ignore = runReceiver(.))

    return(rv)
}
