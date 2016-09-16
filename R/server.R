#' wait for new data files to arrive, then process them
#'
#' Watch the \code{incoming} directory and when a file or folder is
#' written or moved to it, process it.  Processing is delegated based
#' on the name of the file or folder like so:
#'
#' \enumerate{
#' \item if the name has a known form, call the "typed"
#' handler corresponding to the appropriate slot in the name
#' \item otherwise, call a sequence of "free" handlers until one of them
#' returns \code{TRUE}, indicating it has handled the file/folder.
#' }
#' 
#' Handlers are meant to perform small, self-contained tasks, such as
#' unpacking a compressed archive, parsing an email for downloadable
#' links, updating a receiver database with new files, etc.  This
#' helps limit the effect of failure of one task.  Moreover, we try to
#' ensure that files are named and left in places where they will
#' automatically be retried if this server function has to be
#' restarted, or can be dealt with manually.
#'
#' Files or folders already in the watched directory are processed
#' before any new ones, on the assumption that a previous call to this
#' function was interrupted.
#'
#' @param typedHandlers list of functions, one of which will be called when
#' an incoming file or folder has a name of known form, that includes a handler
#' type. Each typed handler function takes these parameters:
#'
#' \itemize{
#'
#' \item path: the full path to the new file or directory
#'
#' \item isdir: boolean; TRUE iff the path is a directory
#'
#' \item params: character vector of parameters parsed from the
#' file/folder name
#'
#' }
#' and returns TRUE or FALSE, according to whether handling succeded.
#'
#' @param freeHandlers list of functions to be called when the name of
#'     an incoming file or folder does not have a recognized form.
#'     Handlers are called one at a time until one of them returns
#'     TRUE.
#'
#' Each free handler function takes these parameters:
#'
#' \itemize{
#'
#' \item path: the full path to the new file or directory
#'
#' \item isdir: boolean; TRUE iff the path is a directory
#'
#' }
#'
#' @param tracing boolean scalar; if TRUE, enter the debugger before
#' each handler is called
#' 
#' Successful handlers will typically move some or all of the files in
#' \code{path} to another location.
#'
#' The file or folder at \code{path} will be deleted if any handler
#' returns TRUE, otherwise it will be filed for manual intervention.
#'
#' The default value of \code{typedHandlers} is:
#' \code{
#' list(
#'          msg      = handleEmail,
#'          url      = handleDownloadableLink,
#'          log      = handleLog,
#'          dta      = handleDTA,
#'          dtaold   = handleDTAold,
#'          sg       = handleSG,
#'          sgold    = handleSGold
#' )
#' }
#'
#' The default value of \code{freeHandlers} is:
#' \code{
#' list(
#'          archive  = handleArchive,
#'          default  = handlePath
#' )
#' }
#'
#' @return This function does not return; it is meant for use in an R
#'     script run in the background.
#'
#' @note If a directory is added by creating a symlink to it in the
#'     \code{incoming} directory, ownership of files in the directory
#'     remains with the files' creator, and this function will not
#'     delete them.  Otherwise, ownership is assumed by this function,
#'     and files are deleted if any handler returns TRUE.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

server = function(typedHandlers, freeHandlers, tracing=FALSE) {
    if (missing(typedHandlers)) {
        typedHandlers = list (
         msg      = handleEmail,
         url      = handleDownloadableLink,
         log      = handleLogs,
         dta      = handleDTAs,
         dtaold   = handleDTAold,
         sg       = handleSGs,
         sgold    = handleSGold
        )
    }
    if (missing(freeHandlers)) {
        freeHandlers = list (
            archive = handleArchive,
            path    = handlePath
        )
    }

    ## sanity checks for handlers
    lapply(typedHandlers,
           function(h) {
               if (! is.function(h) || ! identical(names(formals(h)), c("path", "isdir", "params")))
                   stop("Typed handler must be a function with formals 'path', 'isdir', and 'params'")
               }
           )

    lapply(freeHandlers,
           function(h) {
               if (! is.function(h) || ! identical(names(formals(h)), c("path", "isdir")))
                   stop("Free handler must be a function with formals 'path' and 'isdir'")
               }
           )

    ensureServerDirs()

    ## launch inotifywait to report copying into, moving into, and
    ## link creation in the spool directory; report events and
    ## filenames.  Everything after the first colon is part of the
    ## path to the file

    evtCon = pipe(
        paste("inotifywait -q -m -e close_write -e moved_to -e create --format %e:%f", MOTUS_PATH$QUEUE),
        "r")

    ## initialize file queue with list of files in watch directory.
    
    ## Some of these might be created after starting evtCon but
    ## before calling dir(), so that we see them twice.
    ## Deal with this by keeping track of existing files.
    ## i.e. the queue looks like this:
    ##
    ## 1     ---+
    ## 2        |
    ## ...      +--- files existing before dir()
    ## n     ---+
    ##
    ## n + 1 ---+
    ## n + 2    |
    ## n + 3    +--- files created before dir() but after inotifywait is active
    ## ...      |    These files are seen twice:  once from calling dir()...
    ## n + m ---+    
    ##
    ## n + m + 1 --+
    ## n + m + 2   |
    ## ...         +--- and this second time, from the inotifywait pipe
    ## n + 2m   ---+
    ##
    ## n + 2m + 1 ---+
    ## n + 2m + 2    |--- files created after dir()
    ## ...        ---+

    ## m will usually be zero, but that can't be guaranteed.
    
    existing = queue = dir(MOTUS_PATH$QUEUE)

    motusLog("Server started")

    repeat {
        ## process the queue; it will typically have only 1 element
        while (length(queue) > 0) {
            motusLog("Handling event %s", queue[1])
            p = file.path(MOTUS_PATH$QUEUE, queue[1])
            isdir = file.info(p)$isdir

            ## parse item name to see if it requires a typed handler
            pieces = regexPieces(MOTUS_QUEUEFILE_REGEX, queue[1])[[1]]
            params = strsplit(pieces["params"], "_", fixed=TRUE)[[1]]
            hname = params[1]
            params = params[-1]
            h = typedHandlers[[hname]]

            handled = FALSE

            if (isTRUE(is.function(h))) {
                ## try the appropriate typed handler:
                if (tracing)
                    browser()
            
                tryCatch(
                {
                    handled <- h(path=p, isdir=isdir, params = params)
                }, error = function(e) {
                    motusLog("Exception while running typed handler %s: %s", hname, e)
                })
            } else {
                ## try free handlers until one succeeds
                for (i in seq(along = freeHandlers)) {
                    if (tracing)
                        browser()
            
                    tryCatch(
                    {
                        handled <- freeHandlers[[i]](path=p, isdir=isdir)
                        if (isTRUE(handled)) {
                            break
                        }
                    }, error = function(e) {
                        motusLog("Exception while running free handler %s: %s", hname, e)
                    })
                }
            }
            if (isTRUE(handled)) {
                unlink(p, recursive=TRUE)
                motusLog("Handled by %s", hname)
            } else {
                embroilHuman(p, "No handlers worked for this item.")
            }
            ## drop file/dir from queue
            queue = queue[-1]
        }
        ## wait for a new file/dir
        f = readLines(evtCon, n=1)
        f = sub("^[^:]*:", "", f)
        if (f %in% existing) {
            ## we've seen this event; it's part of the doubly-detected set (see above)
            next
        }
        ## event is new; so we're finished with any double-detections
        existing = c()
        queue = f
    }
}
