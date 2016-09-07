#' Save a handled email message in the appropriate place
#'
#' Both valid and invalid emails are compressed and archived.
#'
#' @param path character scalar path to file containing the emailwhere the message
#'
#' @param valid boolean: is the message valid?
#'#'
#' @return no return value
#''
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

archiveMessage = function(path, valid) {
    outf = paste0(
        file.path(
            if (valid) MOTUS_PATH$EMAILS else MOTUS_PATH$SPAM,
            basename(path)
        ),
        ".bz2"
    )
    writeLines(readLines(path), bzfile(outf, "wb"))
}
