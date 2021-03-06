% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/safeSrcSQLite.R
\name{safeSrcSQLite}
\alias{safeSrcSQLite}
\title{open a dplyr::src to an sqlite database, without the locking issue}
\usage{
safeSrcSQLite(path, create = FALSE)
}
\arguments{
\item{path}{path to database}

\item{create}{should database be created if it doesn't already exist; default: FALSE}
}
\value{
a dplyr::src_sqlite object.
}
\description{
By default, \code{dbConnect(RSQLite::SQLite(), ...)} connects and immediately
tries to set synchronous mode.  If the database is locked, this
fails \emph{before we can use pragma busy_timeout} to set a timeout handler.
This can be circumvented if \code{synchronous=NULL} is added to the
call to dbConnect.
}
\details{
So this function just augments \code{dplyr::src_sqlite} with that workaround.
}
\note{
parameters, return value, and semantics are identical to
\code{\link{dplyr::src_sqlite}} except that a locked sqlite database
will be handled gracefully with retries.
}
\seealso{
\code{\link{safeSQLiteConnect}} which this function calls.
}
\author{
minor changes from dplyr::src_sqlite by John Brzustowski
}
