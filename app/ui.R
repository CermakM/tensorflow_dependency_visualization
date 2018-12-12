# ui.R

library(shiny)


# Define UI for application that plots random distributions 
shinyUI(fluidPage(
  
  titlePanel("TensorFlow transitive dependencies", windowTitle='Shiny App'),
  shiny::helpText(
    withTags({
      a(href="https://github.com/thoth-station", "Thoth Station")
    })
  ),
  
  br(),
  
  
  sidebarLayout(
    sidebarPanel(
      
      selectInput(
        'centrality',  'Centrality measure', 
        choices=c('betweenness', 'degree', 'eigen'), selected='eigen',
        multiple=F
      ),
      selectInput(
        'plot_kind',  'Kind of Plot', 
        choices=c('threejs', 'force', 'diagonal'), selected='force',
        multiple=F
      ),
    
      fluidRow(
        column(6, checkboxInput('grouped', 'Group versions', value=T)),
        column(6, checkboxInput('labels', 'Toggle labels', value=F))
      ),
      
      br(),
      
      sliderInput('charge', label='Charge', min=-100, max=0, value=-100, animate=TRUE),
      
      br(),
      
      sliderInput('centrality_impact', label='Centrality impact', min=0, max=1000, value=10, animate=TRUE)
      
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
      
      tabsetPanel(type = "tabs",
                  tabPanel("Network", uiOutput("network")),
                  tabPanel("About", verbatimTextOutput("about")),
                  tabPanel("Credits", verbatimTextOutput("credits"))
      )
    )
  )
))
