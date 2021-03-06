% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dataServer.R
\name{deviceID_for_receiver}
\alias{deviceID_for_receiver}
\title{get deviceIDs for receiver serial numbers}
\usage{
deviceID_for_receiver(env)
}
\arguments{
\item{serno}{character vector of serial numbers}
}
\value{
a list with these vector items:
   \itemize{
      \item serno; character receiver serial numbers
      \item deviceID; integer device ID
   }
}
\description{
get deviceIDs for receiver serial numbers
}
