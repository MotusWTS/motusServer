% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/handleUploadProcessed.R
\name{handleUploadProcessed}
\alias{handleUploadProcessed}
\title{handler for completion of processing of an uploaded file}
\usage{
handleUploadProcessed(j)
}
\arguments{
\item{j}{the job}
}
\value{
TRUE always.
}
\description{
Sends a message to the uploader giving the status of processing.
If \code{topJob(j)} has an item named \code{emailAttachment},
then that is a list of named file attachments which will be
included in the summary message.
}
\seealso{
\code{\link{emailServer}}, \code{\link{processServer}}
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
