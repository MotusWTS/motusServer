#' Create a copse, a persistent structure for holding R objects with a tree
#' structure.
#'
#' Manage collections of persistent objects.
#'
#' This function is a factory for an S3 class ("Copse") that uses an
#' SQLite database to store R objects of class ("Twig") which are
#' related as one or more trees.  Each Twig holds a named set of
#' plain-old-data R objects stored in a JSON field, and zero or more
#' user-specified fixed fields, stored as SQLite columns. Twig get/set
#' semantics use \code{$} and \code{$[[]]}; i.e. they work like
#' environments.  Within an R process, Twigs are copied by reference
#' so that there's really only one version of any Twig. Changes to
#' Twigs are recorded atomically to the SQLite database, so that other
#' processes also have access to them.  An atomic get/modify/set
#' operation can be performed on a Twig by using the \code{with()}
#' method.
#'
#' The copse manages these functions:
#' \itemize{
#'  \item create the database table
#'  \item get Twigs from the DB
#'  \item put Twigs to the DB when they change in R
#'  \item record timestamps for Twig creation and modification
#' }
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
#'       stump INTEGER REFERENCES <table> (id), -- ID of ultimate ancestor, if any
#'       ctime FLOAT(53),                       -- twig creation time, unix timestamp
#'       mtime FLOAT(53),                       -- twig modification time, unix timestamp
#'       ...
#'       data  JSON                             -- JSON-serialized object data
#'    )
#' }
#' where \code{...} represents additional user-specified columns present in all twigs.
#'
#' The \code{...} columns can be considered the structurally constant
#' part of a Copse, while the \code{data} column holds the
#' structurally variable part.
#'
#' @return This function creates an object of class "Copse".  It has these S3 methods:
#' \itemize{
#' \item newTwig(Copse, ..., .parent=NULL): new twig with the named items in (...), and with parent Twig .parent
#' \item Copse[[TwigID]]: twig(s) with given ID(s) or NULL
#' \item Copse[query, sort]: twig(s) satisfying query, in order by sort criterion
#' \item child(Copse, Twig, n): nth child of given twig, or NULL
#' \item children(Copse, Twig): Twigs which are children of Twig
#' \item childrenWhere(Copse, Twig, expr): Twigs which are children of Twig and satisfy the expression
#' \item numChildren(Copse, Twig): number of children of Twig
#' \item parent(Copse, Twig): all Twigs which are parents to given Twig(s)
#' \item stump(Copse, Twig): Twigs which are ultimate ancestors to given Twig(s)
#' \item query(Copse, query): run an arbitrary sql query on the Copse
#'
#' \item setParent(Copse, Twig1, Twig2): set parent of Twig1 to be Twig2
#'
#' \item with(Copse, expr): evaluate \code{expr} within a transaction
#'       on the Copse database; this provides atomic get-modify-set semantics across
#'       processes accessing the same Copse.  If an error occurs while evaluating \code{expr},
#'       the transaction is rolled back.
#' }
#'
#' Internally a Copse uses these symbols:
#' \itemize{
#' \item sql: safeSQL connection object to DB
#' \item db: path to db
#' \item table: name of table in DB
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
#' \item parent(Twig): get parent Twig of Twig, or NULL if it has none
#' \item stump(Twig): ultimate ancestor of Twig, or NULL if none
#' \item parent<-(Twig, Twig): set parent of Twig to Twig with ID TwigID (can pass a Twig instead):
#' \item child(Twig, n): get nth child of Twig, or NULL if it doesn't exist
#' \item children(Twig): get list of IDs of children of Twig
#'
#' \item childrenWhere(Twig, expr): list of child Twigs for which
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
#' Internally, a Twig is a numeric vector of class "Twig" with attribute Copse
#' being the Twig's Copse.
#'
#' @examples
#'
#' hats = Copse("/home/john/inventory.sqlite", "hats")
#' b = newTwig(hats, name="bowler", size=22, colour="black")
#' h = hats[id < 10 || .$size > 20]  ## query can involve id, pid, mtime, ctime, fixed columns, or data variables selected using .$...$...[]...
#' h[[1]]
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

Copse = function(db, table, ...) {
    sql = safeSQL(db)
    fixed = list(...)
    if (length(fixed) > 0) {
        fixedTypes = c(
            "numeric" = "FLOAT(53)",
            "integer" = "INTEGER",
            "logical" = "INTEGER",
            "character" = "TEXT"
        ) [sapply(fixed, class)]
        extraCols = paste(names(fixed), fixedTypes, ",", collapse="\n")
        extraIndex = paste0("CREATE INDEX IF NOT EXISTS ", table, "_", names(fixed), " ON ", table, " (", names(fixed), ")", ";")
    } else {
        extraCols = ""
        extraIndex = character()
    }

    have = dbExistsTable(environment(sql)$con, table)
    if (have) {
        haveTypes = sql(paste("pragma table_info(", table, ")"))
        haveTypes = subset(haveTypes, ! name %in% c("id", "pid", "stump", "mtime", "ctime", "data"))
        if (length(fixed) > 0 && ! identical(sort(haveTypes$name), sort(names(fixed))))
            stop("table exists but its column names\n   (", paste(sort(haveTypes$name), collapse=","), ")\ndon't match those specified:\n   (", paste(sort(names(fixed)), collapse=","), ")")
        fixed = structure(haveTypes$type, names=haveTypes$name)
    }
    sql(paste("
CREATE TABLE IF NOT EXISTS", table, "(
 id INTEGER UNIQUE PRIMARY KEY NOT NULL,
 pid INTEGER REFERENCES", table, "(id),
 stump INTEGER REFERENCES", table, "(id),
 ctime FLOAT(53),
 mtime FLOAT(53),",
extraCols,"
 data JSON)"))
    sql(paste("CREATE INDEX IF NOT EXISTS", paste0(table,"_pid"), "ON", table, "(pid)"))
    sql(paste("CREATE INDEX IF NOT EXISTS", paste0(table,"_stump"), "ON", table, "(stump)"))
    for (i in seq(along=extraIndex))
        sql(extraIndex[i])
    rv = new.env(parent=emptyenv())
    rv$sql = sql
    rv$table = table
    rv$db = db
    rv$fixed = fixed
    return(structure(rv, class="Copse"))
}

#' @export

print.Copse = function(x, ...) {
    n = x$sql(paste("select count(*) from", x$table))[[1]]
    cat("Copse with", n, "Twigs in table",x$table, "of database", x$db, "\n")
}

## FIXME: put all this stuff in separate files in its own package

#' @export

newTwig.Copse = function(C, ..., .parent=NULL) {
    now = as.numeric(Sys.time())

    ## create the empty twig
    C$sql(paste("insert into", C$table, "(pid, stump, ctime, mtime) values (:pid, (select ifnull(stump, id) from", C$table, "where id=:pid), :ctime, :mtime)"),
            pid = if (is.null(.parent)) NA else .parent[1], ## subscript to drop class
            ctime = now,
            mtime = now
            )
    ## get its ID
    twigID = C$sql("select last_insert_rowid()") [[1]]

    ## instantiate that twig
    T = C[[twigID]]

    ## set the stump to itself, if null
    if (is.null(stump(T)))
        C$sql(paste("update", C$table, "set stump=id where id=", twigID))

    setData(T, list(...))
    return(T)
}

#' @export

child.Copse = function(C, t, n) {
    if (! inherits(t, "Twig"))
        stop("t must be a Twig")
    C[[C$sql(paste("select id from", C$table, "where pid=", t, "limit 1 offset", n-1))[[1]] ]]
}

children.Copse = function(C, t) {
    if (! inherits(t, "Twig"))
        stop("t must be a Twig")
    C[[ C$sql(paste("select id from", C$table, "where pid=", t, "order by id"))[[1]] ]]
}

#' @export

numChildren.Copse = function(C, t) {
    if (! inherits(t, "Twig"))
        stop("t must be a Twig")
    C$sql(paste("select count(*) from", C$table, "where pid=", t))[[1]]
}

#' @export

parent.Copse = function(C, t) {
    if (! inherits(t, "Twig"))
        stop("t must be a Twig")
    ids = C$sql(paste("select pid from", C$table, "where pid is not null and id in (", paste(t, collapse=","), ")"))[[1]]
    C[[ ids ]]
}

#' @export

stump.Copse = function(C, t) {
    if (! inherits(t, "Twig"))
        stop("t must be a Twig")
    ids = C$sql(paste("select stump from", C$table, "where id in (", paste(t, collapse=","), ")"))[[1]]
    C[[ ids ]]
}

#' set the parent (and stump) of Twig(s)
#' @export

setParent.Copse = function(C, t1, t2) {
    if (! all(sapply(list(t1, t2), inherits, "Twig")))
        stop("t1 and t2 must both be a Twig")
    if (length(t2) > 1)
        stop("Can only specify a single twig as parent")
    C$sql(paste("update", C$table, "set pid=", t2, ", stump=(select ifnull(stump, id) from", C$table, "where id=", t2, ") where id in (", paste(t1, collapse=","), ")"))
}

#' @export

`[.Copse` = function(C, expr, sort) {
    ## expr: expression that uses json1 paths
    pf = parent.frame()
    e = deparse(Reval(substitute(expr), pf), control=c())
    if (missing(sort)) {
        s = ""
    } else {
        s = paste("ORDER BY", deparse(Reval(substitute(sort), pf), control=c()))
    }
    C[[ C$sql(paste("select id from", C$table, "where", rewriteQuery(e), s))[[1]] ]]
}

#' To support syntactic sugar like Jobs[! done && type=="email"]$done = 1,
#' create idempotent methods:

#' @export

`[<-.Copse` = function(C, expr, sort, value) {
    return(C)
}

#' @export

`[[<-.Copse` = function(C, expr, value) {
    return(C)
}

#' @export

`$<-.Copse` = function(C, name, value) {
    return(C)
}


#' @export

`[[.Copse` = function(C, twigID) {
    if (length(twigID) == 0 || ! isTRUE(all(is.finite(twigID))))
        return(NULL)

    twigID = as.integer(twigID)

    ## check twig existence
    existing = C$sql(paste("select id from", C$table, "where id in (",
                           paste(twigID, collapse=","),
                           ")"))[[1]]

    if (length(existing) > 0)
        return(structure(existing, class="Twig", Copse=C))
    else
        return(NULL)
}

#' find children of Twig which satisfy a query
#' @export

childrenWhere.Copse = function(C, T, expr) {
    ## expr: expression that uses json1 paths
    pf = parent.frame()
    e = deparse(Reval(substitute(expr), pf), control=c())
    C[[ C$sql(paste("select id from", C$table, "where pid in (", paste(T, collapse=","), ") and (", rewriteQuery(e), ")"))[[1]] ]]
}

#' evaluate portions of an expression enclosed in \code{R( )},
#' returning the reduced expression.
#'
#' This allows query expressions to include portions to be
#' evaluated in R before converting the remaining expression into
#' an SQLite:json1 query
#'
#' @param e an expression.

Reval = function(e, env) {
    if (! is.call(e))
        return(e)
    if(e[[1]]=="R")
        return(eval(e[[2]], env))
    if (length(e) > 1)
        for(i in 2:length(e))
            e[[i]] = Reval(e[[i]], env)
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
        "&"  = " AND ",
        "|"  = " OR ",
        "!=" = "<>",
        "==" = "=",
        "!"  = " NOT "
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

with.Copse = function(C, expr, ...) {
    C$sql("savepoint copse")
    .rollback = TRUE
    on.exit(C$sql(if (.rollback) "rollback to copse" else "release copse"))
    ## any access to Twigs in C in expr are now within a transaction
    eval(substitute(expr), parent.frame(2))
    .rollback = FALSE
}

#' @export

print.Twig = function(x, ...) {
    C = copse(x)
    cat("Twig(s) with id(s)", paste(x, collapse=","), "from table", C$table, "in database", C$db, "\n")
}

names.Twig = function(T) {
    C = copse(T)
    C$sql(paste("select key from", C$table, "as t1, json_each(data) where t1.id=", T[1]))[[1]]
}

#' @export

`[[.Twig` = function(T, name) {
    C = copse(T)
    C$sql("savepoint copse")
    .rollback = TRUE
    on.exit(C$sql(if(.rollback) "rollback to copse" else "release copse"))
    fr = paste0("from ", C$table, " where id in (", paste(T, collapse=","), ")")
    if (name %in% names(C$fixed)) {
        rv = C$sql(paste("select", name, fr))[[1]]
    } else {
        xs = paste0("'$.",name,"'")
        type = C$sql(paste0("select json_type(data,", xs, ")", fr))[[1]][1]
        rv = C$sql(paste("select json_extract(data,", xs, ")", fr))[[1]]
        if (isTRUE(type == "object" || type == "array"))
            rv = fromJSON(rv)
        else if (isTRUE(is.na(type)))
            rv = NULL
    }
    .rollback = FALSE
    return(rv)
}

#' @export

`$.Twig` = function(T, name) {
    `[[.Twig`(T, substitute(name))
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
    C = copse(T)
    C$sql("savepoint copse")
    .rollback = TRUE
    on.exit(C$sql(if(.rollback) "rollback to copse" else "release copse"))

    if (missing(values)) {
        values = names
        names = names(values)
    }
    if (length(names) == 1)
        values = list(values)

    wh = paste0("where id in (", paste(T, collapse=","), ")")
    if (clearOld)
        C$sql(paste("update", C$table, "set data='{}'", wh))

    for(i in seq(along=names)) {
        if (names[i] %in% names(C$fixed)) {
            C$sql(paste("update", C$table, "set ", names[i], "=:value", wh), value=values[[i]])
        } else {
            C$sql(paste("update", C$table, "set data=json_set(ifnull(data, '{}'), '$.' ||:name, json(:value))", wh),
                  name = names[i],
                  value = unclass(toJSON(values[[i]], auto_unbox=TRUE, digits=NA))
                  )
        }
    }
    now = as.numeric(Sys.time())
    C$sql(paste("update", C$table, "set mtime=:mtime", wh),
          mtime = now
          )
    .rollback = FALSE
    return(T)
}

#' @export

parent.Twig = function(T) {
    parent(copse(T), T)
}

#' @export
stump.Twig = function(T) {
    stump(copse(T), T)
}

#' @export

`parent<-.Twig` = function(T, value) {
    setParent(copse(T), T, value)
    return(T)
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

children.Twig = function(T) {
    children(copse(T), T)
}

#' @export

childrenWhere.Twig = function(T, expr) {
    pf = parent.frame()
    e = rewriteQuery(deparse(Reval(substitute(expr), pf), control=c()))
    C = copse(T)
    C$sql(paste("select id from", C$table, "where", paste0('(', e, ') and pid in (', paste(T, collapse=","), ")")))[[1]]
}

#' @export

copse.Twig = function(T) {
    attr(T, "Copse")
}

#' @export

mtime.Twig = function(T) {
    C = copse(T)
    C$sql(paste("select mtime from", C$table, "where id in (", paste(T, collapse=","), ")"))[[1]]
}

#' @export

ctime.Twig = function(T) {
    C = copse(T)
    C$sql(paste("select ctime from", C$table, "where id in (", paste(T, collapse=","), ")"))[[1]]
}

#' @export

blob.Twig = function(T) {
    unclass(toJSON(get("data", envir=parent.env(T), inherits=FALSE), auto_unbox=TRUE, digits=NA))
}

#' @export

delete.Twig = function(T) {
    C = copse(T)
    C$sql(paste("delete from", C$table, "where id in (", paste(T, collapse=","), ")"))
}

#' @export

parent = function(T, ...) UseMethod("parent")

#' @export

stump = function(T, ...) UseMethod("stump")

#' @export

childrenWhere = function(T, ...) UseMethod("childrenWhere")

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

numChildren = function(C, ...) UseMethod("numChildren")

#' @export

child = function(C, ...) UseMethod("child")

#' @export

children = function(C, ...) UseMethod("children")

#' @export

parent = function(C, ...) UseMethod("parent")

#' @export

stump = function(C, ...) UseMethod("stump")

#' @export

query = function(C, ...) UseMethod("query")

#' @export

setParent = function(C, ...) UseMethod("setParent")

#' @export

twigsWhere = function(C, ...) UseMethod("twigsWhere")
