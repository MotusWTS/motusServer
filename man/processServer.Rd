% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/processServer.R
\name{processServer}
\alias{processServer}
\title{process batches of files from the queue}
\usage{
processServer(N, tracing = FALSE)
}
\arguments{
\item{N}{integer queue number. If in the range 1..8, this process
will watch for new jobs in \code{MOTUS_PATH$QUEUE0} and will
store its operations in the folder \code{MOTUS_PATH$QUEUE\emph{N}}
If \code{N >= 101}, the process will watch for new jobs in
\code{MOTUS_PATH$PRIORITY}.  This is to allow high-priority jobs to run separately
from those handling uploaded data.  It's meant for manual runs on
the server, and runs for small batches of data from attached receivers.}

\item{tracing}{boolean scalar; if TRUE, enter the debugger before
each handler is called}
}
\value{
This function does not return; it is meant for use in an R
    script run in the background.  After each subjob is handled,
    the function checks for the existence of a file called
    \code{MOTUS_PATH$QUEUE0/kill\emph{N}} or
    \code{MOTUS_PATH$PRIORITY/kill\emph{N}} (for N >= 101)
    If that file is found,
    the function calls quit(save="no").  The file will also
    be detected within the call to feed() when the queue
    is empty, because it is located in the watched folder.
}
\description{
The queue consists of items in the \code{MOTUS_PATH$QUEUE<N>}
folder.  When the queue is empty, it is fed an item from the
\code{MOTUS_PATH$QUEUE0} folder, which receives processed email messages
and directly moved folders.
}
\details{
Processing an item in the queue usually leads to more items being
added to the queue, and these are processed in depth-first order;
i.e. if X1 is a subjob of X and Y1 is a subjob of Y, and X was
created before Y, and X1 and Y1 are both in the queue, then X1 will
be processed before Y1, regardless of which was enqueued first.
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
