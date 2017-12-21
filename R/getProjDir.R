#' Get the directory where files for a project are stored.
#'
#' @param p integer scalar; motus project ID
#'
#' @param isTesting logical scalar; is this for a test job?
#' Default: FALSE
#'
#' @return character scalar; the path to the project directory.
#'
#' @note As a side-effect, the project directory will be created and populated
#' with appropriate files (e.g. header.html) if it does not already exist.
#'
#' @details processing job marked with `isTesting` store their products in
#' a special testing tree
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getProjDir = function(p, isTesting=FALSE) {
    p = as.integer(p)
    d = file.path(if(isTesting) MOTUS_PATH$TEST_WWW else MOTUS_PATH$WWW, p)
    if (file.exists(d))
        return(d)

    ## create the folder with appropriate permissions, and add header.html
    ## and .htaccess files

    ## see whether the project is already in our cached meta data

    pn = MetaDB("select name from projs where id=:id", id=p)[[1]]
    if (length(pn) == 0) {
        projs = motusListProjects()
        pn = projs$name[projs$id == p]
        if (length(pn) == 0) {
            stop("motus project ", p, " does not exist")
        }
    }

    dir.create(d, mode="0775")

    cat(sprintf("<h3>Motus Project %d.  %s</h3>\n", p, pn), file=file.path(d, "header.html"))
    cat(sprintf('
AuthType None
require valid-user
TKTAuthToken %d
', p), file=file.path(d, ".htaccess"))

    return(d)
}
