% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getRecvDBPath.R
\name{getRecvDBPath}
\alias{getRecvDBPath}
\title{Get the path to a receiver database given its serial number.}
\usage{
getRecvDBPath(serno, dbdir = MOTUS_PATH$RECV)
}
\arguments{
\item{serno}{receiver serial number}

\item{dbdir}{path to folder with existing receiver databases
Default: \code{MOTUS_PATH$RECV}}
}
\value{
a character scalar giving the full path to the receiver database,
or NULL if \code{serno} is not a valid receiver serial number
}
\description{
receiver database files are stored in a single directory, and
have names like "SG-XXXXBBBKYYYY.motus" or "Lotek-NNNNN.motus"
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
