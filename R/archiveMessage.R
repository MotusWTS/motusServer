#' Save a handled email message in the appropriate place
#'
#' Both valid and invalid emails are logged.
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

        system(sprintf("cat %s | /usr/bin/lzip -o %s", path,
                       file.path( if (valid) MOTUS_PATH_EMAILS else MOTUS_PATH_SPAM,
                                 basename(path))
                       )
               )
}
