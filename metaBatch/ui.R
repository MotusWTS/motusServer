source("matcher.R")

motusProjects <<- motusListProjects()

shinyUI(
    navbarPage(
        "MotusMeta",
        tabPanel(
            "Spreadsheet",
            fileInput(
                "inputFile",
                "Choose an xls or xlsx spreadsheet",
                accept=c("application/xls", "application/xlsx")
            ),
            textOutput("File info"),
            uiOutput("chooseSheet")
        ),
        tabPanel(
            "Input Table",
            uiOutput("inputTable")
        ),
        tabPanel(
            "Projects",
            headerPanel('Match your projects to Motus Projects'),
##            matcherInput('matchList', 'yourProject', "motusProject", c("ten", "nine", "eight", "seven", "six", "one", "two", "three", "four", "five", "something else"), motusProjects$name, size=15),
##            matcherInput('matchList', 'yourProject', "motusProject", c("ten", "nine", "eight", "seven", "six", "one", "two", "three", "four", "five", "something else"), c("this", "is", "a", "test", "of", "something"), size=15),
            textOutput("matchInds")
            )
    )
)


