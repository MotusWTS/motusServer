#' return a vector of subjobs of the given topjob which are in the queue
#'
#' @param tj a Twig object representing the topjob.  It must have \code{parent(tj) = NULL}
#'
#' @return NULL, if no subjobs of \code{tj} are in the queue, otherwise a vector
#' with class "Twig" of job IDs.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

subjobsInQueue = function(tj) {
    return(MOTUS_QUEUE[grepl(sprintf("^%08d", tj), names(MOTUS_QUEUE), perl=TRUE)])
}
