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
        choices=c('threejs', 'force', 'diagonal'), selected='threejs',
        multiple=F
      ),
      checkboxInput('grouped', 'Group versions', value=T)
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
      
        uiOutput('network')
        
    )
  )
))
