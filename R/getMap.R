#' Access (maybe after creating) a persistent named list in a database.
#'
#' This function creates an object of S3 class "motusMap", which behaves
#' like a named list, allowing access via the \code{$} and \code{[[
#' ]]} operators.  Elements assigned to the list are immediately
#' stored in table \code{name} in the database pointed to by
#' \code{src}.  An element can be removed from the list by assigning
#' NULL to it.
#'
#' @param src dplyr src_sqlite to a database or an SQLiteConnection
#'
#' @param name name of table in database; default: "meta"
#'
#' @return an object of class "motusMap".
#'
#' @export
#'
#' @examples
#'
#' x = getMap(safeSrcSQLite("SG-1234BBBK5678.motus"), "meta")
#' x$recvSerno
#' x$MACAddr <- "01235a3be098"
#' x$recvSerno <- NULL
#' x[["MACAddr"]]

getMap = function(src, name="meta") {
    if (inherits(src, "SQLiteConnection"))
        con = src
    else
        con = src$con
    if (! dbExistsTable(con, name))
        dbGetQuery(con, sprintf("create table '%s' (key text primary key, val text);", name))
    return(structure(paste("Map", name), name=name, con=con, class="motusMap"))
}

#' get the key values of a map table in a database
#'
#' @param map object of class "motusMap"
#'
#' @return character vector; all keys in the map
#'
#' @export

names.motusMap = function(map) {
    return (dbGetQuery(attr(map, "con"), sprintf("select key from %s", attr(map, "name")))[[1]])
}

#' set an element in a motus map
#'
#' Set the value associated with a key in the given map.
#'
#' @param map object of class "motusMap", as created by \code{motusMap}
#'
#' @param key key of item, as character scalar
#'
#' @param val character string value to associate with \code{key}
#'
#' @export
#'

`[[<-.motusMap` = function(map, key, value) {
    if (! is.null(value))
        dbGetQuery(attr(map, "con"), sprintf("insert or replace into %s (key, val) values (:key, :val)", attr(map, "name")), params=data.frame(key=key, val=value, stringsAsFactors=FALSE))
    else
        dbGetQuery(attr(map, "con"), sprintf("delete from %s where key=:key", attr(map, "name")), params=data.frame(key=key))
    return(invisible(map))
}

#' set an element in a motus map
#'
#' Set the value associated with a key in the given map.
#'
#' @param map object of class "motusMap", as created by \code{motusMap}
#'
#' @param key key of item, as bare symbol
#'
#' @param val character string value to associate with \code{key}
#'
#' @export
#'

`$<-.motusMap` = function(map, key, value) {
    `[[<-.motusMap`(map, substitute(key), value)
}

#' Return the value of an item from a motusMap.
#'
#' @param map object of class "motusMap"
#'
#' @param key character scalar; name of item in map
#'
#' @return character scalar; value associated with \code{key}.
#'
#' @export

`[[.motusMap` = function(map, key) {
    return (dbGetQuery(attr(map, "con"), sprintf("select val from %s where key=:key", attr(map, "name")), params=data.frame(key=key, stringsAsFactors=FALSE))[[1]])
}

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
    `[[.motusMap` (map, substitute(key))
}
