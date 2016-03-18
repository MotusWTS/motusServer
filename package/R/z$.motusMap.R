#' Return the value of an item from a motusMap.
#'
#' @param map object of class "motusMap"
#'
#' @param key character scalar; name of item in map
#'
#' @return character scalar; value associated with \code{key}.
#'
#' @export

`$.motusMap` = function(map, key) {
    return (dbGetPreparedQuery(attr(map, "con"), sprintf("select val from %s where key=:key", attr(map, "name")), data.frame(key=substitute(key), stringsAsFactors=FALSE))[[1]])
}
