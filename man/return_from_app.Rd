% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/return_from_app.R
\name{return_from_app}
\alias{return_from_app}
\title{return an object from a Rook app}
\usage{
return_from_app(rv, isJSON = FALSE)
}
\arguments{
\item{rv}{the object to return.}

\item{isJSON}{logical; is `rv` already JSON?  If so, serialization
of `rv` to JSON is skipped.  Default: FALSE}
}
\value{
the return value suitable as a return value for a Rook app.
    This is the result of calling \code{Rook::Response}'s
    \code{finish()} method.
}
\description{
This includes generating headers, bzip2-compressing the object payload, and
returning the response.  Even app errors are returned by this function,
through a call to \link{\code{error_from_app}}.  If the env() variable
in the parent frame contains a value called `HTTP_ACCEPT_ENCODING` and
that value includes the string "gzip", then as a special case, this
function returns its data gzip-compressed with header `Content-Encoding: gzip`.
This is to support directly calling this API from client-side javascript, which
in Firefox, at least, doesn't support bzip2-compression.
}
\note{
This function is called to return a value by all API entries
    supported by this package.  These are implemented as Rook apps
    as part of \link{\code{dataServer}} or
    \link{\code{statusServer}}
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
