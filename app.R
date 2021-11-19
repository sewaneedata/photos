################################################################################
################################################################################
# Shiny app
################################################################################
################################################################################

# Load dependencies
library(shiny)
library(shinyjs)
library(dplyr)
library(readr)
library(ggthemes)
library(ggplot2)
library (leaflet)
library(slickR)

# Bring in functions for analyzing photos and interacting with AWS S3 bucket
source('function-s3.R')

# Allow uploading large photos - up to 30 MB
options(shiny.maxRequestSize = 30*1024^2)

################################################################################
################################################################################
# Function to load in data (and re-load from within the app)

load_photo_data <- function(local_only=FALSE){

    # local_only = Running locally, or can you connect to the s3 bucket?

    # Gather predictions and image metadata
    df <- gather_predictions(local_only)
    meta <- gather_image_metadata(local_only)

    # Prep those two datasets for joining
    #head(df)
    file_core <- gsub('&&&','/',df$file)
    file_core <- gsub('processed/results/','',file_core)
    file_core <- sapply(strsplit(file_core,'.',fixed=TRUE),'[[',1)
    df$file_core <- file_core
    head(df$file_core)

    #head(meta)
    meta$SourceFile <- NULL
    file_core <- sapply(strsplit(meta$FileName,'.',fixed=TRUE),'[[',1)
    meta$file_core <- file_core
    head(meta$file_core)

    # Join them
    df <- left_join(df,meta,by='file_core')
    head(df)

    return(df)
}

################################################################################
################################################################################

# Define UI for application that draws a histogram
ui <- fluidPage(
    shinyjs::useShinyjs(),
    # Application title
    titlePanel("Haiti Institute in Sewanee: Photograph analysis"),
    br(),
    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            uiOutput('label_name'),
            br(),br(),br(),
            fileInput("img", "Select image to process",
                      multiple = TRUE,
                      accept = c('.jpg','.JPG','.jpeg','.JPEG')),
            uiOutput('process'),
            br(),br(),br(),
            actionButton('refresh','Try refreshing results'),
            br(),
            checkboxInput('local_only','Only use local data to refresh?', value=TRUE),
            br(),br(),
            helpText('System updates:'),
            textOutput('text'),
            br(),br()


        ),

        mainPanel(
            tabsetPanel(
                tabPanel(h4('Trends'),
                         fluidRow(column(12,plotOutput("selectPlot")))
                ),
                tabPanel(h4('Data'),
                         br(),
                        fluidRow(column(12,DT::dataTableOutput('predictions')))
                ),
                tabPanel(h4('Images'),
                         #fluidRow(column(12,uiOutput('show_image')))
                         br(),
                         fluidRow(column(6,h3('Examples of photographic analysis:')),
                                  column(6,br(),actionButton('img_page_next','Download next batch of examples',width='95%'))),
                         fluidRow(column(1),
                                  column(10,slickROutput('show_image')),
                                  column(1))
                ),
                tabPanel(h4('About'),
                         br(),
                         fluidRow(column(12,HTML("<b>The Haiti Institute In Sewanee Program </b>is a center for collaborative educational partnerships between Haiti and Sewanee. </br></br>Through a wide collection of projects, the Haiti Institute in Sewanee Program aims to promote scholarship research across a wide range of disciplines both in Sewanee and in Haiti.
One of the projects of the Institute is to promote economic development in a community of farmers through a variety of avenues. One of the strategies to track this economic development involved giving 10 cameras to 10 farmer families. </br></br>The instructions given to them were strategically photographic and intentionally less about the content of the photographs.
</br></br>The idea was to document as much as possible about their daily lives. This project started in 2009 and has collected more than 2400 photographs and is still ongoing.
	In the summer of 2021, the Sewanee Datalab used convolutional neural networks for object detection in the photographs' contents. Once predictions were made, they were used to create this dashboard that quantifies the contents of the photos and shows the frequency of objects over a certain period of time.")))
                         )
            )
        )
    )
)

################################################################################
################################################################################

# Define server logic required to draw a histogram
server <- function(input, output) {

    # Stage reactive values
    rv <- reactiveValues()
    rv$refresh_ticker <- 0
    rv$df <- data.frame()
    rv$most_recent_image <- NULL
    rv$img_page <- 0
    rv$tmp <- NULL
    rv$update_gallery <- 0

    #observe({
    #    rv$refresh_ticker <- rv$refresh_ticker + 1
    #})

    observe({
        rv$refreshticker
        withCallingHandlers({
            shinyjs::html("text","")
            isolate({df_reloaded <- load_photo_data(local_only=input$local_only)})
            message('Standing by')
            rv$df <- df_reloaded
        },
        message=function(m){shinyjs::html(id="text",html=m$message,add=FALSE)}
        )

    })

    output$label_name <- renderUI({
        req(rv$df)
        df <- rv$df
        choices <- sort(unique(df$label))
        selectInput("label_name", "Select object",
                  choices = choices,
                  selected=choices[which(choices == 'cell phone')],
                  multiple = TRUE)
    })

    output$process <- renderUI({
        if(!is.null(input$img) & !input$local_only){
            actionButton('process','Process photo(s)')
        }
    })

    observeEvent(input$process,{
        local_files <- input$img$datapath
        withCallingHandlers({
            shinyjs::html("text","")
            df <- analyze_local_photo_s3(input$img)
        },
        message=function(m){shinyjs::html(id="text",html=m$message,add=FALSE)}
        )
        print(df)
        if(nrow(df)>0){
            rv$most_recent_image <- df$label_img
            rv$refresh_ticker <- rv$refresh_ticker + 1
        }
    })

    observeEvent(input$refresh,{
        rv$refreshticker <- rv$refreshticker + 1
    })

    output$selectPlot <- renderPlot({
        req(rv$df, input$label_name)

        if(TRUE){

        df <- rv$df
        years <- range(df$year,na.rm=TRUE)
        results <- data.frame()
        for(this_year in years[1]:years[2]){
            df_year <- df %>% filter(year==this_year)
            for(this_label in input$label_name){
                df_label <- df_year %>% filter(label == this_label)
                this_count <- nrow(df_label)
                this_prop <- nrow(df_label) / nrow(df_year)
                this_result <- data.frame(year=this_year,
                                          label=this_label,
                                          frequency=this_count,
                                          proportion=this_prop)
                results <- rbind(results,this_result)
            }
        }

        if(nrow(results)>0){
         ggplot(data = results, aes(x= year, y = frequency, fill = label)) +
            geom_bar(stat='identity', position = position_dodge(width = 0.9)) +
            geom_text(aes(label = frequency), vjust = -0.5,
                      position = position_dodge(width = 0.9))

        }
        }
    })

    output$predictions <- DT::renderDataTable({rv$df})

    # Step forward to next page of images
    observeEvent(input$img_page_next,{
        rv$img_page <- rv$img_page + 1
        withCallingHandlers({
            shinyjs::html("text","")
            dimg <- download_image_batch(n_images = 10,
                                         page_i = rv$img_page)
        },
        message=function(m){shinyjs::html(id="text",html=m$message,add=FALSE)}
        )
        message('Standing by')
        print(dimg$img)

        rv$tmp <- dimg$tmp
        rv$update_gallery <- rv$update_gallery + 1
    })

    output$show_image <- renderSlickR({
        rv$update_gallery

        photodir <- 'images_labelled/'
        if(!is.null(rv$tmp)){
            photodir <- paste0(rv$tmp,'/')
            print(photodir)
        }
        photos <- dir(photodir)
        imgs <- paste0(photodir,photos)
        slickR(imgs, height=600)
    })

}

################################################################################
################################################################################

# Run the application
shinyApp(ui = ui, server = server)
