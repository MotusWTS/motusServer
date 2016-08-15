#' Process a new batch of files from a receiver.
#'
#' Merge the files into the receiver database, and run the tag
#' finder on each boot session for which new input was provided,
#' either in new files, or longer versions of existing files.
#'
#' If all usable files for a boot session are more recent than files we
#' already have, the tag finder is run in "resume" mode, so that only
#' the new files are processed.  This is the usual situation,
#' especially for online SGs, and avoids the growth in processing time
#' that would occur if boot sessions were re-run from scratch with
#' each incremental file upload.
#'
#' Otherwise, if any new files for a boot session predate existing
#' ones, the entire boot session is re-run.
#'
#' @param files either a character vector of full paths to files, or
#'     the full path to a directory, which will be searched
#'     recursively for raw sensorgnome data files.
#'
#' @param dbdir path to folder with existing receiver databases
#' Default: \code{/sgm/recv}
#'
#' @param par additional paramters to the tag finder
#'
#' @return NULL so far.
#'
#' @export
#'
#' @seealso \code{sgMergeFiles} and \code{sgFindTags}, which this function calls.
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgRunNewFiles = function(files, dbdir = "/sgm/recv", par="") {
    r = sgMergeFiles(files, dbdir) %>% arrange(serno, monoBN) %>% group_by(serno, monoBN)

    ## a function to process files from each boot session:

    runBootSession = function(f) {
        ## nothing to do if no files to use

        if (! any(f$use))
            return(0)

        ## grab src for this receiver
        s = sgRecvSrc(f$serno[1])

        ## get latest timestamp of existing files in this boot session
        bn = f$monoBN[1]

        lastTS = tbl(s, "files") %>% filter_(monoBN=bn) %>% summarise_(m = max(ts)) %>% collect %>% as.data.frame

        canResume = min(f$ts) > lastTS

        sgFindTags(s, getMotusMetaDB(), resume=canResume, par=par, mbn=bn)
    }

    r %>% do (rv = runBootSession(.))
}
