#' Create a copse, a persistent structure for holding R objects with a tree
#' structure.
#'
#' Manage collections of persistent objects.
#'
#' This function is a factory for an S3 class ("Copse") that uses an
#' SQLite database to store R objects of class ("Twig") which are
#' related as one or more trees.  Each Twig holds a named set of
#' plain-old-data R objects (i.e. those representable in JSON). Twigs
#' get/set semantics use \code{$} and \code{$[[]]}; i.e. they work
#' like environments.  Each Twig's data is shared across all instances
#' in the workspace, and changes are recorded atomically to the SQLite
#' database, so that other processes also have access to them.
#'
#' The copse manages these functions:
#' \itemize{
#'  \item create the database table
#'  \item get twigs from the DB
#'  \item put twigs to the DB when they change in R
#'  \item record timestamps for twig creation and modification
#'  \item ensure uniqueness of twig data
#'  \item garbage collect unused twigs out of the workspace
#' }
#'
#' Changes are made atomically using SQLite locking, so that processes can
#' share a copse, and so twigs are always in a consistent state on disk.
#'
#' @param db path to sqlite database with the copse table.  This will
#' be created if it doesn't exist.
#'
#' @param table name of sqlite table in the database.  This will be created
#' if it doesn't exist in \code{db}, with this schema:
#' \preformatted{
#'    CREATE TABLE <table> (
#'       id    INTEGER UNIQUE PRIMARY KEY,
#'       pid   INTEGER REFERENCES <table> (id), -- ID of parent twig, if any
#'       ctime FLOAT(53),                       -- twig creation time, unix timestamp
#'       mtime FLOAT(53),                       -- twig modification time, unix timestamp
#'       data  JSON                             -- JSON-serialized object data
#'    )
#' }
#'
#' @return This function creates an object of class "Copse".  It has these S3 methods:
#' \itemize{
#' \item newTwig(Copse, ..., .parent=NULL): new twig with the named items in (...), and with parent Twig .parent
#' \item twigWithID(Copse, TwigID): twig with given ID or NULL
#' \item child(Copse, TwigID, n): nth child of given twig, or NULL
#' \item childIDs(Copse, Twig): list of Twig IDs which are children of Twig
#' \item numChildren(Copse, Twig): number of children of Twig
#' \item parent(Copse, Twig): Twig which is parent to given twig
#' \item parent<-(Copse, Twig, TwigID): set Twig which is parent to given twig
#' \item parentID(Copse, TwigID): ID of Twig which is parent to twig with given ID
#' \item query(Copse, query): run an arbitrary sql query on the Copse
#'
#' \item twigIDsWhere(Copse, expr): list of TwigIDs for which given
#'       expr is TRUE.  The expression is applied against the data field
#'       of each row.  The identifier "." stands for the item's top
#'       level, so the third element of a numeric vector called 'blam'
#'       would be represented as \code{'.$blam[3]'} in \code{expr}
#'
#' \item setTwigParent(Copse, TwigID1, TwigID2): set parent of TwigID1 to be TwigID2
#' }
#'
#' Internally a Copse uses these symbols:
#' \itemize{
#' \item sql: safeSQL connection object to DB
#' \item db: path to db
#' \item table: name of table in DB
#' \item map: environment mapping twigIDs to environments, to maintain uniqueness of twigs
#' }
#'
#' Twigs are S3 objects of class "Twig" with these S3 methods:
# S3 methods:
#' \itemize{
#' \item $(Twig, name): return value of name in Twig, with name an unquoted symbol
#' \item $<-(Twig, name, value): set value of name in Twig, with name an unquoted symbol
#' \item [[(Twig, name): return value of name in Twig, with name a quoted character scalar
#' \item [[<-(Twig, name, value): set value of name in Twig, with name a quoted character scalar
#' \item names(Twig): list names in Twig
#' \item twigID(Twig): get ID of Twig
#' \item parent(Twig): get parent Twig of Twig, or NULL if it has none
#' \item parentID(Twig): get ID of parent Twig of Twig, or NULL if it has none
#' \item parent<-(Twig, TwigID): set parent of Twig to Twig with ID TwigID (can pass a Twig instead):
#' \item child(Twig, n): get nth child of Twig, or NULL if it doesn't exist
#' \item childIDs(Twig): get list of IDs of children of Twig
#'
#' \item childIDsWhere(Twig, expr): list of child TwigIDs for which
#'       given expr is TRUE.  The expression is applied against the
#'       data field of each row.  The identifier "." stands for the
#'       item's top level, so the third element of a numeric vector
#'       called 'blam' would be represented as \code{'.$blam[3]'} in
#'       \code{expr}
#'
#' \item numChildren(Twig): get number of children of Twig
#' \item copse(Twig): get Copse object that owns Twig
#' \item mtime(Twig): twig creation time, as unix timestamp
#' \item ctime(Twig): twig modification time, as unix timestamp
#' \item blob(Twig): twig data JSON-serialized
#' \item setData(Twig, names, values, clearOld=FALSE): set named data items for twig; if clearOld is TRUE, delete all existing data first. As a shortcut, if values is missing, treat names as a named list, rather than a char vector of names.  Uses a single DB query to set all items.
#' \item delete(Twig): called only from garbage collection; reduces the use count of the real twig, dropping it from its Copse's map when the count reaches zero
#'}
#'
#' Internally, a Twig uses these symbols:
#' \itemize{
#' \item  copse: environment of owning Copse
#' \item  id: integer ID
#' \item  pid: integer parent ID
#' \item  ctime: unix creation timestamp
#' \item  mtime: unix modification timestamp
#' \item  data: all named objects stored in this list
#' \item  uc: use count of (real) twig
#' }
#'
#' @examples
#'
#' hats = Copse("/home/john/inventory.sqlite", "hats")
#' b = newTwig(hats, name="bowler", size=22, colour="black")
#' hid = listTwigIDs(hats, "id < 10")  ## query can involve id, pid, mtime, ctime
#' h1 = twigWithID(hats, h[1])
#' ## grow a bit; change will be written to DB immediately
#' h1$size = h1$size * 1.10
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

Copse = function(db, table) {
    sql = safeSQL(db)
    sql(paste("
CREATE TABLE IF NOT EXISTS", table, "(
 id INTEGER UNIQUE PRIMARY KEY NOT NULL,
 pid INTEGER REFERENCES", table, "(id),
 ctime FLOAT(53),
 mtime FLOAT(53),
 data JSON)"))
    sql(paste("CREATE INDEX IF NOT EXISTS", paste0(table,"_pid"), "on", table, "(pid)"))
    rv = new.env(parent=emptyenv())
    rv$sql = sql
    rv$table = table
    rv$db = db
    rv$map = new.env(parent=emptyenv())
    return(structure(rv, class="Copse"))
}

## FIXME: put all this stuff in separate files in its own package

#' @export

newTwig.Copse = function(C, ..., .parent=NULL) {
    now = as.numeric(Sys.time())

    ## create the empty twig
    C$sql(paste("insert into", C$table, "(pid, ctime, mtime) values (:pid, :ctime, :mtime)"),
            pid = if (is.null(.parent)) NA else twigID(.parent),
            ctime = now,
            mtime = now
            )
    ## get its ID
    twigID = C$sql("select last_insert_rowid()") [[1]]

    ## instantiate that twig
    T = twigWithID(C, twigID)

    setData(T, list(...))
    return(T)
}

#' @export

twigWithID.Copse = function(C, twigID) {
    if (! isTRUE(is.finite(twigID)))
        return(NULL)

    ## check if twig already exists
    sid = as.character(twigID)

    if (! exists(sid, envir=C$map)) {
        ## load twig from DB
        twig = C$sql(paste("select * from", C$table, "where id=", twigID))
        if (! isTRUE(nrow(twig) == 1))
            return(NULL)

        twig = as.environment(twig)
        twig$copse = C
        if (is.na(twig$data))
            twig$data = list()
        else
            twig$data = fromJSON(twig$data)
        twig$uc = 0  ## use count initially zero but will be incremented below
        C$map[[sid]] = twig
    }
    ## bump up use counter
    C$map[[sid]]$uc <- C$map[[sid]]$uc + 1
    rv = structure(new.env(parent=C$map[[sid]]), class="Twig")
    reg.finalizer(rv, delete.Twig)
    return(rv)
}

#' @export

child.Copse = function(C, t, n) {
    if (inherits(t, "Twig"))
        t = twigID(t)
    twigWithID(C, C$sql(paste("select id from", C$table, "where pid=", t, "limit 1 offset", n-1))[[1]])
}

childIDs.Copse = function(C, t) {
    if (inherits(t, "Twig"))
        t = twigID(t)
    C$sql(paste("select id from", C$table, "where pid=", t))[[1]]
}

#' @export

numChildren.Copse = function(C, t) {
    if (inherits(t, "Twig"))
        t = twigID(t)
    C$sql(paste("select count(*) from", C$table, "where pid=", t))[[1]]
}

#' @export

parentID.Copse = function(C, t) {
    if (inherits(t, "Twig"))
        return(parentID(t))
    C$sql(paste("select pid from", C$table, "where id=", t))[[1]]
}

#' @export

parent.Copse = function(C, t) {
    twigWithID(C, parentID(C, t))
}

#' @export

setTwigParent.Copse = function(C, T, t) {
    if (inherits(T, "Twig"))
        T = twigID(T)
    if (inherits(t, "Twig"))
        t = twigID(t)
    if (! isTRUE(all(is.finite(c(T, t)))))
        stop("Parameters are not twigs or twig IDs")
    C$sql(paste("update", C$table, "set pid=", t, "where id=", T))
    T = as.character(T)
    ## update parent for in-memory copy
    if (exists(T, envir=C$map))
        C$map[[T]]$pid=t
}

#' @export

twigIDsWhere.Copse = function(C, expr) {
    ## expr: expression that uses json1 paths
    e = deparse(Reval(substitute(expr)))
    C$sql(paste("select id from", C$table, "where", rewriteQuery(e)))[[1]]
}

#' evaluate portions of an expression enclosed in \code{R( )},
#' returning the resulting, possibly reduced, expression
#' This allows query expressions to include portions to be
#' evaluated in R before converting the remaining expression into
#' an SQLite:json1 query
#'
Reval = function(e) {
    if (! is.call(e))
        return(e)
    if(e[[1]]=="R")
        return(eval(e[[2]]))
    if (length(e) > 1)
        for(i in 2:length(e))
            e[[i]] = Reval(e[[i]])
    return(e)
}

rewriteQuery = function(q) {
    ## translate stringified query into a json1-compatible query
    ##
    ## json1 "paths" look like $NAME((.NAME) | ([NUM]))*
    ## where NAME are symbols, and NUM are integers
    ##
    ## In \code{expr}, the user specifies paths in R style, i.e.:
    ## .$NAME(($NAME) | ([NUM]))*
    ## where "." is an identifier representing the top level.
    ## We can switch from one representation to another using
    ## regular expression substitution; we're essentially just
    ## swapping '$' and '.'
    ##
    ## Example:
    ## rewriteQuery( .$a[3]$b - 2 * pi >= id

    pathrx = "(?<![[:alnum:]])\\.[[:space:]]*\\$[[:space:]]*([[:alpha:]][[:alnum:]]*)(?:[[:space:]]*(?:(?:\\$[[:space:]]*[[:alpha:]][[:alnum:]]*)|(?:\\[[[:space:]]*[1-9][0-9]*[[:space:]]*\\])))*"
    m = gregexpr(pathrx, q, perl=TRUE)
    paths = regmatches(q, m)[[1]]
    new = gsub("[[:space:]]*", "", paths, perl=TRUE)

    ## To swap '$' and '.' via sequential gsub(), we
    ## substitute:  .$ -> @, $ -> ., @ -> json_extract(data, ... )
    new = paste0("json_extract(data, '", new, "')")

    subs = c(
        ".$" = "@",
        "$" = ".",
        "@" = "$."
    )
    for (i in seq(along=subs))
        new = gsub(names(subs)[i], subs[i], new, fixed=TRUE)

    regmatches(q, m) = list(new)

    ## replace operators;
    subs = c(
        "&&" = " AND ",
        "||" = " OR ",
        "!=" = "<>",
        "==" = "=",
        "!" = " NOT "
    )
    for (i in seq(along=subs))
        q = gsub(names(subs)[i], subs[i], q, fixed=TRUE)

    return(q)
}

#' @export

query.Copse = function(C, ...) {
    C$sql(...)
}

#' @export

listTwigIDs.Copse = function(C, query) {
    C$sql(paste("select id from", C$table, "where", query))[[1]]
}

#' @export

names.Twig = function(T) {
    names(parent.env(T)$data)
}

#' @export

`$.Twig` = function(T, name) {
    get("data", envir=parent.env(T))[[substitute(name)]]
}

#' @export

`[[.Twig` = function(T, name) {
    get("data", envir=parent.env(T))[[name]]
}

#' @export

`$<-.Twig` = function(T, name, value) {
    setData(T, substitute(name), value)
}

#' @export

`[[<-.Twig` = function(T, name, value) {
    setData(T, name, value)
}

#' @export

setData.Twig = function(T, names, values, clearOld=FALSE) {
    P = parent.env(T)
    C = copse(T)
    if (clearOld)
        assign("data", list(), envir=P)
    if (missing(values)) {
        for(i in seq(along=names)) {
            P$data[[names(names)[i]]] = names[[i]]
        }
    } else {
        for(i in seq(along=names)) {
            P$data[[names[i]]] = values[[i]]
        }
    }
    now = as.numeric(Sys.time())
    C$sql(paste("update", C$table, "set data=:data, mtime=:mtime where id=:id"),
          data = blob(T),
          id = P$id,
          mtime = now
          )
    P$mtime = now
    return(T)
}

#' @export

twigID.Twig = function(T) {
    get("id", envir=parent.env(T))
}

#' @export

parent.Twig = function(T) {
    parent(copse(T), T)
}

#' @export

`parent<-.Twig` = function(T, value) {
    setTwigParent(copse(T), T, value)
    return(T)
}

#' @export

parentID.Twig = function(T) {
    get("pid", envir=parent.env(T))
}

#' @export

numChildren.Twig = function(T) {
    numChildren(copse(T), T)
}

#' @export

child.Twig = function(T, n) {
    child(copse(T), T, n)
}

#' @export

childIDs.Twig = function(T) {
    childIDs(copse(T), T)
}

#' @export

childIDsWhere.Twig = function(T, expr) {
    e = rewriteQuery(deparse(Reval(substitute(expr))))
    C = copse(T)
    C$sql(paste("select id from", C$table, "where", paste0('(', e, ') and pid==', twigID(T))))[[1]]
}

#' @export

copse.Twig = function(T) {
    get("copse", envir=parent.env(T))
}

#' @export

mtime.Twig = function(T) {
    get("mtime", envir=parent.env(T))
}

#' @export

ctime.Twig = function(T) {
    get("ctime", envir=parent.env(T))
}

#' @export

blob.Twig = function(T) {
    unclass(toJSON(get("data", envir=parent.env(T), inherits=FALSE), auto_unbox=TRUE, digits=NA))
}

#' @export

delete.Twig = function(T) {
    C = copse(T)
    tid = as.character(twigID(T))
    C$map[[tid]]$uc = C$map[[tid]]$uc - 1
    if (C$map[[tid]]$uc == 0)
        remove(list=tid, envir=C$map)
}

#' @export

`==.Twig` = function(x, y) isTRUE(twigID(x)==twigID(y))

#' @export

twigID = function(T, ...) UseMethod("twigID")

#' @export

parent = function(T, ...) UseMethod("parent")

#' @export

parentID = function(T, ...) UseMethod("parentID")

#' @export

childIDsWhere = function(T, ...) UseMethod("childIDsWhere")

#' @export

`parent<-` = function(T, ...) UseMethod("parent<-")

#' @export

copse = function(T, ...) UseMethod("copse")

#' @export

mtime = function(T, ...) UseMethod("mtime")

#' @export

ctime = function(T, ...) UseMethod("ctime")

#' @export

blob = function(T, ...) UseMethod("blob")

#' @export

setData = function(T, ...) UseMethod("setData")

#' @export

delete = function(T, ...) UseMethod("delete")

#' @export

newTwig = function(C, ...) UseMethod("newTwig")

#' @export

twigWithID = function(C, ...) UseMethod("twigWithID")

#' @export

numChildren = function(C, ...) UseMethod("numChildren")

#' @export

child = function(C, ...) UseMethod("child")

#' @export

childIDs = function(C, ...) UseMethod("childIDs")

#' @export

parent = function(C, ...) UseMethod("parent")

#' @export

parentID = function(C, ...) UseMethod("parentID")

#' @export

listTwigIDs = function(C, ...) UseMethod("listTwigIDs")

#' @export

query = function(C, ...) UseMethod("query")

#' @export

setTwigParent = function(C, ...) UseMethod("setTwigParent")

#' @export

twigIDsWhere = function(C, ...) UseMethod("twigIDsWhere")
