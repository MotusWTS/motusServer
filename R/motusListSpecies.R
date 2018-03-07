#' return a list of species IDs for the given codes or names
#'
#' @param qstr [optional] Query string to filter the list of species
#'     (e.g. Warbler or YRWA). Unless the language parameter is
#'     specified, this will search within the following fields and
#'     return all possible hits: English name, French name, Scientific
#'     name and Species code.
#'
#' @param nrec  maximum number of records returned by the request (max: 20,000); default 100
#'
#' @param group [optional] Taxonomic group used to search for species
#'     names( e.g. BIRDS). Refer to the listspeciesgroups entry points
#'     for values. When not provided, search among entire species
#'     taxonomy.  Default: "BIRDS"
#'
#' @param qlang [optional] The language used to search for
#'     species. One of the following possible values: EN (English), FR
#'     (French), SC (Scientific), CD (Species code).
#'
#' @param ... [optional] extra parameters for \code{motusQuery()}
#'
#' @return if any matches were found, they are returned as a dataframe
#' with these columns:
#' \enumerate{
#' \item id; integer ID of species
#' \item english character; english-language name of species
#' \item french character; french-language name of species
#' \item scientific character; scientific name of species
#' \item group character; e.g. "BIRDS"
#' \item sort integer sorting order
#' }
#' Otherwise, NULL is returned.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListSpecies = function(qstr = NULL,
                            nrec = NULL,
                            group = "BIRDS",
                            qlang = c("all", "EN", "FR", "SC", "CD"),
                            ...) {
    colsNeeded = c("id", "english", "french", "scientific", "group", "sort")

    qlang = match.arg(qlang)
    if (qlang == "all")
        qlang = NULL
    rv = motusQuery(MOTUS_API_LIST_SPECIES, requestType="get",
               c(
                   list(
                       qstr = qstr,
                       nrec = nrec,
                       group = group,
                       qlang = qlang
                   ),
                   list( ...)
               )
               )
    if (! isTRUE(nrow(rv) > 0))
        return(NULL)

    ## fill in any missing columns, then return in stated order
    for (col in colsNeeded) {
        if (is.null(rv[[col]]))
            rv[[col]] = NA
    }
    return(rv[, colsNeeded])
}
