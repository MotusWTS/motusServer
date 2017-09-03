#' determine the model from a sensorgnome serial number
#'
#' The serial number determines the receiver model.  We use the form
#' SG-XXXXMMMMYYYY where MMMM is the model, and XXXXYYYY are the true
#' serial number.
#'
#' @param serno character scalar; receiver serial number, e.g. "SG-1234BBBKABCD"
#'
#' @return a character scalar with the receiver model, which so far is one of:
#' \itemize{
#' \item BBBK - beaglebone black
#' \item BBW -  beaglebone white
#' \item RPI2 - raspberry Pi model 2B
#' \item RPI3 - raspberry Pi model 3B
#' \item RPIZ - raspberry Pi model Z wireless
#' }
#'
#' @details the model is stored more or less as-is in the serial number string,
#' but BBW might have a digit that's not always zero immediately following
#' the 'BB'.  This function is meant to allow flexibility for future
#' serial numbers.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getSGModel = function(serno) {

    ## get model portion of string
    model = toupper(substring(serno, 8, 12))

    switch(model,
           "BBBK" = "BBBK",
           "RPI2" = "RPI2",
           "RPI3" = "RPI3",
           "RPIZ" = "RPIZ",
           "BBW")
}
