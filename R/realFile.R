#' follow any symlinks, returning the path to a normal file
#' or folder
#'
#' Given a path, there are some file operations where we want to be
#' sure we're dealing with the real file, and not a symlink to it.
#' For a vector of paths, this function follows any symlinks along
#' each path, returning the ultimate normal file or directory as a
#' target.
#'
#' @param paths character vector of paths
#'
#' @return character value of the same length as \code{path}, with any
#'     symlinks followed so that each item returned is a path to a
#'     normal file or folder.  For any item in \code{path} which
#'     doesn't exist, or for which the last symlink target doesn't exist,
#'     or for which there is a symlink loop, returns \code{NA}.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

realFile = function(path) {
    ## keep track of which paths have been visited for each item
    seen = as.list(path)

    repeat {
        targ = Sys.readlink(path)

        ## if we reach a path we've seen before for a given item, mark
        ## it as an error, since it's a symlink loop

        bad = which(sapply(seq(along=targ), function(i) targ[i] %in% seen[[i]]))
        targ[bad] = NA

        ## record any new destinations
        sapply(seq(along=targ), function(i) if (isTRUE(targ[i] != "")) seen[[i]] <<- c(seen[[i]], targ[i]))

        ## if either a link has been followed, or there's an error, update
        ## that item in path

        use = is.na(targ) | targ != ""
        path[use] = targ[use]

        ## if no symlink has been followed (successfully), then we're done
        if (! isTRUE(any(targ != "")))
            return(path)

        ## continue following any symlinks
    }
}
