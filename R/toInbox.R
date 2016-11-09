#' Move a message to the inbox, from where the emailServer will process it.
#'
#' @param path the full path to the message file
#'
#' @return TRUE
#'
#' @seealso \code{\link{emailServer}}
#'
#' @export
#'
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

toInbox = function(path) {
    moveFiles(path, MOTUS_PATH$INBOX)
}
