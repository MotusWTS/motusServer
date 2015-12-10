matcherInput <- function(inputId, leftLabel, rightLabel, leftChoices, rightChoices,
                         size = 5) {
    
    leftChoices <- lapply(leftChoices, tags$option, class="matcher-left-option")
    rightChoices <- lapply(seq(along=rightChoices), function(i)tags$option(rightChoices[[i]], class="matcher-right-option", listInd=i))
    
    tagList(
        singleton(tags$head(
            tags$script(src="matcher-binding.js"),
            tags$style(type="text/css",
                       HTML(".matcher-container { display: inline-block; }")
                       )
        )),
        div(id=inputId, class="matcher",
            div(class="matcher-container matcher-left-container",
                tags$h3(leftLabel),
                tags$select(class="left", size=size, leftChoices)
                ),
            div(class="matcher-container",
                tags$br(),
                HTML("&nbsp;&nbsp;")
                ),
            div(class="matcher-container matcher-right-container",
                tags$h3(rightLabel),
                tags$select(class="right", size=size, rightChoices)
                ),
            div(class="matcher-container matcher-matched-container",
                tags$h3("Matches"),
                tags$select(class="matched", size=size, c())
                ),
            tags$br(),
            tags$br(),
            div(class="matcher-container",
                actionButton("matcherOk", class="matcher-ok", label="Ok"),
                actionButton("matcherCancel", class="matcher-cancel", label="Cancel")
            )
            )
    )
}

registerInputHandler("matcher", function(data, ...) {
    if (is.null(data))
        NULL
    else
        as.integer(unlist(data$blam))
}, force = TRUE)
