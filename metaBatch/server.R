shinyServer(function(input, output, session) {

    output$matchInds <- renderPrint({ input$matchList })

})

