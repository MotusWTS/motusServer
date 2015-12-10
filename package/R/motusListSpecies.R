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
#' @return if any matches were found, they are returned as a dataframe
#' with these columns:
#' \enumerate{
#' \item id - numeric ID of species
#' \item english - english-language name of species
#' \item french - french-language name of species
#' \item scientific - scientific name of species
#' }
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusListSpecies = function(qstr = NULL,
                            nrec = 100,
                            group = "BIRDS",
                            qlang = c("all", "EN", "FR", "SC", "CD")) {
    qlang = match.arg(qlang)
    if (qlang == "all")
        qlang = NULL
    motusQuery(MOTUS_API_LIST_SPECIES, requestType="get",
               list(
                   qstr = qstr,
                   nrec = nrec,
                   group = group,
                   qlang = qlang
               ))
}
