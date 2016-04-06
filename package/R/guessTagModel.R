#' guess the model of a tag used by the speciesID
#'
#' People usually use the largest tag they can reasonably
#' put on an organism, to maximize the length of time over
#' which they can get data.
#' 
#' @param sp integer vector of motus speciesID of the tags
#'
#' @return character vector giving guessed tag model e.g. "NTQB-2"
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

guessTagModel = function(sp) {
    return(speciesTagModel$tagModel[match(sp, speciesTagModel$id)])
}


