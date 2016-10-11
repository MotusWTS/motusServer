#' process incoming emails
#'
#' Watch for new messages in \code{MOTUS_PATH$INBOX}.
#'
#' When a new message is found:
#' \itemize{
#' \item create a new job folder in /sgm/queue/0
#' \item unpack its parts
#' \item validate by looking for an authorization token
#' \item save attachments
#' \item download files from any links
#' \item enqueue a new job with all files
#' \item email the sender with an acknowledgement and pointer to a status page.
#' }
#'
#' @return This function does not return; it is meant for use in an R
#'     script run in the background.
#'
#' @note each of the above steps is encoded as a jobStep
#'
#' @export
#'
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

emailServer = function() {
}
