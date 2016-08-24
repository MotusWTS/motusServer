#' find which tags match registered tags
#'
#' A set of user tags is looked up in a set of motus-registered tags.
#' The user tag set is divided into three subsets: tags with unique, multiple,
#' or no matches in the motus set, respectively.
#' 
#' @param u: user tags; a dplyr::tbl_df object, having at least the
#'     columns representing manufacturer tag ID, burst interval, and
#'     registration year
#'
#' @param m: motus tags; a dplyr::tbl_df object with one
#'     motus-registered tag per row.  Typically, this will be the
#'     result of calling. \code{getProjectTags()}
#'
#' @param id: name of column in \code{u} representing the tags'
#'     manufacturer ID.
#'
#' @param bi: name of column in \code{u} representing burst interval,
#'     in seconds.
#'
#' @param yr: name of column in \code{u} representing tag registration
#'     year.
#'
#' @param bi.digits: number of digits after the decimal point to use
#'     in matching burst interval.  Burst intervals are rounded to
#'     this number of digits before matching.  Defaults to 0, meaning
#'     integer values are used.
#' 
#' @param id.digits: number of digits after the decimal point to use
#'     in matching manufacturer tag ID.  Tags might have been
#'     registered with digits after the decimal point to represent
#'     duplicate IDs distinguished by burst interval in the same year
#'     and project.  IDs are rounded to this number of digits before
#'     matching. Defaults to 0, meaning integer values are used.
#' 
#'
#' @return a list with four items:
#' \enumerate{
#' \item  unique: the join of rows from \code{u} with their unique match in \code{m}, for those
#' user tags with a unique match in the motus tag list
#'
#' \item multi: the join of rows from \code{u} with each of their matchs in \code{m}, for those
#' user tags having multiple matches in the motus tag list
#'
#' \item collide: the join of rows from \code{u} with each of their matchs in \code{m}, for those
#' motus tags having multiple matches in the user tag list; these are collisions
#' in the user tag list.
#'
#' \item none: the rows from \code{u} having no match in \code{m}
#'
#' }
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

matchTags = function(u, m, id, bi, yr, bi.digits=0, id.digits=0) {
    if (! all(c(id, bi, yr) %in% colnames(u)))
        stop("Specified columns are not all present in user tag set")

    rv = list(
        unique = NULL,
        multi = NULL,
        collide = NULL,
        none = NULL
        )

    ## simple case - no user tags given
    if (is.null(u)) 
        return (rv)

    ## simple case - no motus tags given
    if (is.null(m)) {
        rv$none = u ## all tags are unmatched
        return (rv)
    }

    ## modify user set; Can't seem to get this to work properly with mutate

    ## create a unique rowID for the user tag set
    u$.rowID = 1:nrow(u)
            
    ## rounded ID
    u$.iid = as.numeric(u[[id]]) %>% round(id.digits)

    ## rounded burst interval
    u$.ibi = round(u[[bi]], bi.digits)
            
    ## copy year to new name
    u$.yr = u[[yr]]

    
    ## modify motus set

    ## unique row id
    m$.rowID2 = 1:nrow(m)

    ## rounded ID
    m$.iid = as.numeric(m$mfgID) %>% round(id.digits)

    ## add a rounded burst interval
    m$.ibi = round(m$period, bi.digits)
    
    ## registration year
    m$.yr = year(m$tsSG)

    ## row id


    ## join spreadsheet and motus values by ID, burst interval, and year
    ## Note: we're matching on integer tag IDs (`iid`, not `id`) because
    ## the burst interval is being matched separately.

    hit = u %>% inner_join(m, by=c(".iid", ".ibi", ".yr"))

    if (nrow(hit) == 0) {
        rv$none = u    ## remove extra columns from u
    } else {
        
        ## find all rows in join for which the user row matches
        ## multiple motus rows; rowID is the unique ID for each
        ## user tag.
        
        dup = hit$.rowID %in% hit$.rowID[duplicated(hit$.rowID)]

        ## generate return value, removing temporary columns
        rv$none = u %>% filter(! .rowID %in% hit$.rowID)

        rv$unique = hit %>% filter(! dup) 
        rv$multi  = hit %>% filter(  dup)

        ## now look for collisions: motus tag registrations having
        ## multiple user tags matched to them

        motusDup = with(rv$unique, .rowID2 %in% .rowID2[duplicated(.rowID2)])
        rv$collide = rv$unique %>% filter (motusDup)
        rv$unique = rv$unique %>% filter (! motusDup)
    }
    ## remove temporary columns
    for (item in names(rv)) {
        if (! is.null(rv[[item]])) {
            rv[[item]] = rv[[item]] %>% select (-.rowID, -.iid, -.ibi, -.yr)
            if (item != "none") {
                rv[[item]] = rv[[item]] %>% select (-.rowID2)
            }
        }
    }
    return(rv)
}


