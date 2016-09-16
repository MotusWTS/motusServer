#' return a function which returns the next item from a folder.
#'
#' The returned function maintains a queue of path names which is
#' initialized with those files and folders already in
#' \code{incoming}.  Any files or folders subsequently added to
#' \code{incoming} are added to the end of the queue.  Items are
#' typically email messages with attached data files or links to
#' download them, or folders of data files already on the server.
#'
#' @param incoming the full path to the incoming folder.
#'
#' @param tracing boolean; if TRUE, each event on the incoming folder
#' is printed.  Default: FALSE.
#'
#' @return a function with no parameters.  This function returns the
#'     full path to the next available incoming item, or waits if
#'     there are none.
#'
#' @details
#' The algorithm is this:
#'
#' \enumerate{
#' \item initialize file queue with list of files and folders in \code{incoming}.
#' \item use inotifywait to watch \code{incoming} for new files, links, and
#' folders.
#' }
#'
#' There's a race condition in which files might be created after
#' starting to watch \code{incoming} but before calling \code{dir()}
#' to list existing items, so that we see them twice.  Deal with this
#' by keeping track of existing files.  i.e. the queue looks like
#' this:
#'
#' 1     ---+
#' 2        |
#' ...      +--- files existing before inotifywait is active
#' n     ---+
#'
#' n + 1 ---+
#' n + 2    |
#' n + 3    +--- files created after inotifywait is active but before dir()
#' ...      |    These files are seen twice:  once from calling dir()...
#' n + m ---+
#'
#' n + m + 1 --+
#' n + m + 2   |
#' ...         +--- ... and this second time, from the inotifywait pipe
#' n + 2m   ---+
#'
#' n + 2m + 1 ---+
#' n + 2m + 2    |--- files created after dir()
#' ...        ---+
#'
#' m will usually be zero, but that can't be guaranteed.  We retain the list
#' of items 1..n + m, and check inotify events against it. The first item
#' not in that list will be item n + 2m + 1, which is new.
#'
#' @seealso \code{\link{server}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getFeeder = function(incoming, tracing = FALSE) {

    ## watch the directory
    evtCon = pipe(paste("inotifywait -q -m -e close_write -e moved_to -e create --format %e:%f", incoming), "r")

    ## grab list of items already there, with full path, sorted by mtime
    old = dirSortedBy(incoming, "mtime")

    ## index into the vector of old items
    i = 0

    ## create the getter function

    function () {
        ## this closure's local environment has i, old, and evtCon

        if (i < length(old)) {
            ## still have items in the old, so return the current one
            i <<- i + 1
            return (old[i])
        }
        ## wait for a new file/dir
        repeat {
            evt = readLines(evtCon, n=1)
            if (tracing)
                print(evt)
            f = file.path(incoming, sub("^[^:]*:", "", evt))
            if (! f %in% old) {
                ## it's a new event, not part of the doubly-detected set (see above)
                break
            }
        }
        ## we're past the double-detection stage (chronologically), so
        ## empty old to avoid further checking; else we miss new
        ## items with old names
        old <<- character(0)

        ## return the new item, with full path
        return (f)
    }
}