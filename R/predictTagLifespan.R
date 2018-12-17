#' predict the lifespan of specified tag model and burst interval
#'
#' Using data published by Lotek, and a simple fitted model, this
#' function estimates the 80\% lifespan for those tags.
#' The model is lifeSpan = D / (1 + rt * dutyCycle / BI),
#' where D and rt are fitted parameters, dutyCycle is in [0, 1],
#' and BI is the burst interval, in seconds.
#'
#' @param model character vector of tag models
#'
#' @param bi numeric vector; burst interval, in seconds
#'
#' @param dutyCycle fraction of time tag is transmitting. The usual
#'     value, 1.0 is the default. Non-default values would be
#'     specified if using a tag that shuts down at night, e.g.
#'
#' @return predicted lifespan (days).
#'
#' @note for any values in \code{model} which are not known, we use
#' the explicit model "unknown" which is defined in lotekTagLifespanByBatteryAndBI
#' as an average of NTQB-2 and NTQB-3-2.  We warn about this so that
#' the admin user gets a regular reminder of this situation.
#' see:
#'    https://github.com/MotusDev/Motus-TO-DO/issues/327#issuecomment-414180027
#' and:
#'    https://github.com/jbrzusto/motusServer/issues/416
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

predictTagLifespan = function(model, bi, dutyCycle = 1.0) {
    known = model %in% rownames(tagLifespanPars)
    if (! all(known)) {
        warning("Replacing these unknown tag models with the NTQB-2/NTQB-3-2 average:  ",
                paste(unique(model[!known]), collapse=", "))
        model[!known] = "unknown"
    }
    return(as.numeric(tagLifespanPars[model, 1] / (1 + tagLifespanPars[model, 2] * dutyCycle / bi)))
}
