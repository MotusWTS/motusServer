source("matcher.R")

shinyUI(fluidPage(
    headerPanel('Motus Batch Registration'),
    matcherInput('matchList', 'numerals', 'number names', as.character(1:10), c("ten", "nine", "eight", "seven", "six", "one", "two", "three", "four", "five", "something else"), size=10),
    textOutput("matchInds")
))


