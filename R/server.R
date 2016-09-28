#' process items in the motus queue.
#'
#' The queue consists of items in the \code{MOTUS_PATH$QUEUE} folder.
#' When the queue is empty, it is fed an item from the
#' \code{MOTUS_PATH$INCOMING} folder, which receives email messages
#' and directly moved folders.
#'
#' Processing an item in the queue usually leads to more items being
#' added to the queue, and these are processed in chronological order.
#' When the queue is finally empty again, a new item is obtained from
#' the external feed.  This way, each external event has all of its
#' processing conducted before the next event, and interruptions
#' to the server process leave the queue and feed in a coherent
#' state for automatic resumption.
#'
#' Each queue item is handled like so:
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
#' @param typedHandlers list of functions, one of which will be called
#'     when an incoming file or folder has a name of known form that
#'     includes a handler type. Each typed handler function takes
#'     these parameters:
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
#' If a typedHandler failed, the queued item is stored for manual
#' intervention.
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
#'          sgnew    = handleSGnew,
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
#' If free handlers are called for an item and none of them returns
#' TRUE, the item is filed for manual intervention.
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
         log      = handleLog,
         dta      = handleDTA,
         dtaold   = handleDTAold,
         sg       = handleSG,
         sgnew    = handleSGnew,
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

    motusLog("Server started")

    ## get a feed of items from external (asynchronous) sources
    ## this feed is only checked when the internal queue is empty

    feed = getFeeder(MOTUS_PATH$INCOMING, tracing)

    ## Create a global variable to hold the queue of paths to process.
    ## This is initialized with the set of items already in
    ## MOTUS_PATH$QUEUE, sorted by mtime.

    MOTUS_QUEUE <<- dirSortedBy(MOTUS_PATH$QUEUE, "mtime")

    ## process the next item to process from the queue.  If the queue is empty,
    ## wait for an item from the feed.  Note global assignments for MOTUS_QUEUE

    repeat {

        if (length(MOTUS_QUEUE) == 0)
            MOTUS_QUEUE <<- feed()  ## this might might wait a long time

        p = MOTUS_QUEUE[1]
        MOTUS_QUEUE <<- MOTUS_QUEUE[-1] ## drop the item from the queue

        motusLog("Handling item %s", p)
        isdir = file.info(p)$isdir

        ## parse item name to see if it requires a typed handler
        pieces = regexPieces(MOTUS_QUEUEFILE_REGEX, basename(p))[[1]]
        params = strsplit(pieces["params"], "_", fixed=TRUE)[[1]]
        hname = params[1]
        params = params[-1]
        h = typedHandlers[[hname]]

        handled = FALSE

        if (isTRUE(is.function(h))) {
            ## try the appropriate typed handler:
            if (tracing)
                browser()
            loggingTry(
                handled <- h(path=p, isdir=isdir, params = params)
            )
        } else {
            ## try free handlers until one succeeds
            for (i in seq(along = freeHandlers)) {
                hname <- names(freeHandlers)[[i]]
                if (tracing)
                    browser()
                loggingTry(
                    handled <- freeHandlers[[i]](path=p, isdir=isdir)
                )
                if (isTRUE(handled)) {
                    break
                }
            }
        }
        if (isTRUE(handled)) {
            ## once we're confident enough, do this:
            unlink(p, recursive=TRUE)

            ## If debugging, do this:
            ##
            ## try(
            ##     file.rename(p, file.path(MOTUS_PATH$DONE, basename(p))),
            ##     silent=TRUE
            ## )

            motusLog("Handled by %s", hname)
        } else {
            embroilHuman(p, "No handlers worked for this item.")
        }
    }
}
