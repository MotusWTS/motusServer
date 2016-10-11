#' Return the \code{motusJob} object corresponding to a path.
#' An entry in the server database is created.
#'
#' @param path location of job folder.
#'
#' @return This function returns an object of class "motusJob".  The
#'     object is a named integer scalar whose value is the job number,
#'     and whose name is the full path to the new folder.
#' If \code{path} does not refer to a valid job, then return NULL.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

jobAtPath = function(path) {
    if (! grepl("^[0-9]{8}$", basename(path), perl=TRUE))
        return (NULL)
    return(structure(as.integer(basename(path)), names=path, class="motusJob"))
}
