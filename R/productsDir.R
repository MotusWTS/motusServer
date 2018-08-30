#' get the directory for products for a receiver
#'
#' @details The directory is created if it does not exist.
#' Normally, the product folder is MOTUS_PATH$PRODUCTS/\code{serno},
#' but if this is a testing job, then the product folder is
#' MOTUS_PATH$TEST_PRODUCTS/\code{serno}
#'
#' @param serno character scalar; the receiver serial number
#'
#' @param isTesting logical scalar; is this for a testing job?
#' Default: FALSE
#'
#' @return path to the product directory
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

productsDir = function(serno, isTesting=FALSE) {
    mainDir = if (isTesting) MOTUS_PATH$TEST_PRODUCTS else MOTUS_PATH$PRODUCTS
    outDir = file.path(mainDir, serno)
    dir.create(outDir, mode="0770")
    ## give user write permission to just-created directory!
    ## workaround for: https://github.com/MotusDev/Motus-TO-DO/issues/325
    Sys.chmod(outDir)
    return(outDir)
}
