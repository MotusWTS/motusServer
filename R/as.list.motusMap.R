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

    
        

