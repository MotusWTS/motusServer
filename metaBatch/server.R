library(motus)
library(readxl)

nf <- NULL
sheet <- NULL

shinyServer(function(input, output, session) {
    output$chooseSheet <- renderUI(
    {
        f = input$inputFile$datapath
        if (!is.null(f)) {
            nf <<- paste0(f, ".xlsx")
            file.rename(f, nf)
            sheets <- excel_sheets(nf)
        } else {
            sheets <- "(none)"
        };

        list(
            div(class="shiny-html-output"),
            selectInput("sheetChoice", "Choose a sheet",
                        sheets)
            )
    }
    )
##    output$matchInds <- renderPrint({ input$matchList })
    reactive({
        if (!is.null(nf)) {
            cat("sheetChoice = ", input$sheetChoice, "\n")
            sheet <<- read_excel(nf, input$sheetChoice)
            output$inputTable = renderTable(sheet)
        }
    })
})

