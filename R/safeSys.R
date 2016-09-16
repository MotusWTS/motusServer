#' call a shell command safely.
#'
#' Quotes all parameters for a bash-type shell then runs the command with
#' them using \link{\code{system2}}
#'
#' @param cmd full path to the executable file (can be a shell script,
#'     for example)
#'
#' @param ... list of parameters to the command; these are combined
#'     using \code{c()} and then quoted using \link{\code{shQuote()}}
#'
#' @return character vector of the stdout and stderr streams from
#'     running \code{cmd}, one line per item.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

safeSys = function(cmd, ...) {
    ## Note: cmd is already quoted by system2(), but for some reason args are not
    system2(cmd, shQuote(c(...)), stdout=TRUE, stderr=TRUE)
}
