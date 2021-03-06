% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ensureTagProjDB.R
\name{ensureTagProjDB}
\alias{ensureTagProjDB}
\title{make sure a tag project database has the required tables; also, load
custom SQLite extensions on this DB connection.}
\usage{
ensureTagProjDB(src, recreate = c(), projectID)
}
\arguments{
\item{src}{dplyr sqlite src, as returned by \code{dplyr::src_sqlite()}}

\item{recreate}{vector of table names which should be dropped then re-created,
losing any existing data.  Defaults to empty vector, meaning no tables
are recreate.  As a special case, TRUE causes all tables to be dropped
then recreated.}

\item{projectID}{motus project ID; this DB will hold tag detections from
one motus project}
}
\value{
returns NULL (silently); fails on any error
}
\description{
make sure a tag project database has the required tables; also, load
custom SQLite extensions on this DB connection.
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
