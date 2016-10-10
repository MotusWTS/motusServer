#' Call an external program safely, return its output and
#' propagate any error into R.
#'
#' This function provides the sole access point to external programs
#' for this package.
#'
#' If the exit status of the command is non-zero, then this function
#' triggers an error using \code{stop(E)} where the message \code{E}
#' will be a character scalar consisting of the lines written to
#' stderr by the command, pasted together with "\\n".
#'
#' Otherwise, this function returns a character scalar with liens
#' written to stdout by the command, pasted together with "\\n".
#'
#' The point of internalizing errors is so that we save the
#' intermediate files and record a full stack dump.  Otherwise, the
#' server might delete downloaded files, thinking (incorrectly) that
#' it has processed them successfully.
#' 
#' @param cmd full path to the executable file (can be a shell script,
#'     for example)
#'
#' @param ... list of un-named parameters to the command; if
#'     \code{shell == TRUE}, these are quoted as appropriate for
#'     bash-type shell.  Otherwise, they are passed as-is.
#'     Note that any args consisting of a single semicolon (';') will
#'     not be quoted, since they are presumably intended to delimit
#'     commands.
#'
#' @param shell logical scalar; if TRUE, invoke command using a shell;
#' otherwise, invoke cmd directly.
#'
#' @param quote logical scalar; if TRUE (the default) and if
#'     \code{shell == TRUE}, quote individual arguments for the shell
#'
#' @param minErrorCode the smallest integer return value that
#'     indicates an error.  Some programs (e.g. 'grep') violate the
#'     usual convention that 0 = no error, and > 0 indicates an error.
#'     Default: 1
#' 
#' @return character vector of the stdout streams from running
#'     \code{cmd}, one line per item.  This will have attribute "exitCode"
#'     giving the exit code of the command, which will be in the range
#'     \code{0: (minErrorCode - 1)}
#'
#' @note stdout and stderr for the command are redirected to temporary
#'     files which are deleted before this function returns.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

safeSys = function(cmd, ..., shell=TRUE, quote=TRUE, minErrorCode=1) {
    ## redirect stdout, stderr to temporary files
    errFile = tempfile()
    outFile = tempfile()
    on.exit(file.remove(errFile, outFile))

    args = c(...)
    if (shell) {
        if (quote) {
            ## shell-quote args except for semi-colons
            semis = args==";"
            args[! semis] = shQuote(args[! semis])
        }
        command = paste(cmd, paste(args, collapse=" "), ">", outFile, "2>", errFile)
        rv = suppressWarnings(system(command = command, intern = FALSE))
    } else {
        rv = suppressWarnings(system2(cmd, args, stdout=outFile, stderr=errFile))
    }
    if (rv >= minErrorCode) {
        err = sprintf("Error %d from '%s':\n%s",
                      rv,
                      ## paste command as it would look, without redirections
                      paste(cmd, paste(args, collapse=" ")),
                      if(rv == 127) "unable to run command" else textFileContents(errFile)
                      )
        stop(err)
    }
    return (structure(textFileContents(outFile), exitCode=rv))
}
