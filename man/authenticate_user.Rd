% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/authenticate_user.R
\name{authenticate_user}
\alias{authenticate_user}
\title{authenticate a user for a Rook request}
\usage{
authenticate_user(env)
}
\arguments{
\item{env}{Rook request environment}
}
\value{
a JSON list with these items:
\itemize{
\item token character scalar token used in subsequent API calls
\item expiry numeric timestamp at which \code{token} expires
\item userID integer user ID of user at motus
\item projects list of projects user has access to; indexed by integer projectID, values are project names
\item receivers FIXME: will be list of receivers user has access to
}
if the user is authorized.  Otherwise, return a JSON list with a single item
called "error".
}
\description{
This is an app used by the Rook server launched by \code{\link{dataServer}}
Params are passed as a url-encoded field named 'json' in the http POST request.
The return value is a JSON-formatted string
}
\note{
This is simply a convenience wrapper around \link{\code{motusAuthenticateUser}}
}
