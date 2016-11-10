#' Access (maybe after creating) a persistent named list in a database.
#'
#' This function creates an object of class motusMap, which behaves
#' like a named list, allowing access via the \code{$} and \code{[[
#' ]]} operators.  Elements assigned to the list are immediately
#' stored in table \code{name} in the database pointed to by
#' \code{src}.  An element can be removed from the list by assigning
#' NULL to it.
#'
#' @param src dplyr src_sqlite to a database
#'
#' @param name name of table in database; default: "meta"
#'
#' @return an object of class "motusMap".
#'
#' @export
#'
#' @examples
#'
#' x = getMap(src_sqlite("SG-1234BBBK5678.motus"), "meta")
#' x$recvSerno
#' x$MACAddr <- "01235a3be098"
#' x$recvSerno <- NULL
#' x[["MACAddr"]]

getMap = function(src, name="meta") {
    con = src$con
    if (! dbExistsTable(con, name))
        dbGetQuery(con, sprintf("create table '%s' (key text primary key, val text);", name))
    return(structure(paste("Map", name), name=name, con=con, class="motusMap"))
}
