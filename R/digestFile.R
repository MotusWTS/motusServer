#' calculate a digest of a file
#'
#' @param f character scalar; path to file
#' @param algo; algorithm for digest; default: "sha1"
#'
#' @return character scalar lower-case hex sha1 digest
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

digestFile = function(f, algo="sha1") {
    digest::digest(readBin(f, raw(), n=file.size(f)), algo=algo, serialize=FALSE)
}
