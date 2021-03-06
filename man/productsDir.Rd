% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/productsDir.R
\name{productsDir}
\alias{productsDir}
\title{get the directory for products for a receiver}
\usage{
productsDir(serno, isTesting = FALSE)
}
\arguments{
\item{serno}{character scalar; the receiver serial number}

\item{isTesting}{logical scalar; is this for a testing job?
Default: FALSE}
}
\value{
path to the product directory
}
\description{
get the directory for products for a receiver
}
\details{
The directory is created if it does not exist.
Normally, the product folder is MOTUS_PATH$PRODUCTS/\code{serno},
but if this is a testing job, then the product folder is
MOTUS_PATH$TEST_PRODUCTS/\code{serno}
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
