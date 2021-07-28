#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
library(shiny)
library(dplyr)
library(readr)
library(ggthemes)
library(ggplot2)
library (leaflet)
df <-read_csv ("data.csv")
# Define UI for application that draws a histogram
ui <- fluidPage(
    # Application title
    titlePanel("Objects in Photos"),
    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            selectInput("label_name", "Select object",
                        choices = unique(df$label),
                        multiple = TRUE)
        ),
        # Show a plot of the generated distribution
        mainPanel(
            plotOutput("selectPlot")
        )
    )
)
# Define server logic required to draw a histogram
server <- function(input, output) {
    output$selectPlot <- renderPlot({
        select_df <- df %>% filter(label %in% input$label_name)
        ggplot(data = select_df, aes(x= year, y = frequency, fill = label)) +
            geom_bar(stat='identity', position = position_dodge(width = 0.9)) +
            geom_text(aes(label = frequency), vjust = -0.5,
                      position = position_dodge(width = 0.9))
    })
}
# Run the application
shinyApp(ui = ui, server = server)
