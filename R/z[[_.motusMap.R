#' set an element in a motus map
#'
#' Set the value associated with a key in the given map.
#'
#' @param map object of class "motusMap", as created by \code{motusMap}
#'
#' @param key key of item
#'
#' @param val character string value to associate with \code{key}
#'
#' @export
#'

`$<-.motusMap` = function(map, key, value) {
    if (! is.null(value))
        dbGetPreparedQuery(attr(map, "con"), sprintf("insert or replace into %s (key, val) values (:key, :val)", attr(map, "name")), data.frame(key=key, val=value, stringsAsFactors=FALSE))
    else
        dbGetPreparedQuery(attr(map, "con"), sprintf("delete from %s where key=:key", attr(map, "name")), data.frame(key=key))
    return(invisible(map))
}
