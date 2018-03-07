#' Extract an argument from a list ensuring SQL-safety
#'
#' If the list contains an item of the given name, the return value
#' will be that item coerced to the given type. For character strings,
#' single quotes will be doubled so that the object is safe for use in
#' SQL queries, provided that strings are enclosed in single quotes in
#' the query.
#'
#' @return If there is no item with the given name in \code{x},
#' then return NULL.
#'
#' @param x list object with names
#' @param name unquoted object name
#' @param type unquoted type name, one of "character", "integer", "logical", "numeric", "list"
#' or abbreviation thereof.
#' @param scalar if TRUE (the default) return a vector of length 1,
#' dropping any additional items. Otherwise, return a vector with the
#' same length as the item from \code{x}.  If \code{type=="list"}, the
#' vector is of mode "list".
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

safe_arg = function(x, name, type, scalar=TRUE) {
    name = as.character(substitute(name))
    type = as.character(substitute(type))
    if (! name %in% names(x))
        return(NULL)
    class = match.arg(type, c("character", "integer", "logical", "numeric", "list"))

    rv = as(x[[name]], class)
    if (isTRUE(scalar))
        rv = rv[1]
    if (length(rv) == 0 || isTRUE(all(is.na(rv))))
        return(NULL)
    for (i in seq_len(length(rv))) {
        if (class(rv[[i]]) == "character")
            rv[[i]] = gsub("'", "''", rv[[i]])
    }
    return(rv)
}
