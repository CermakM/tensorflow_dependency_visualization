# server.R

library(shiny)

library(tidyverse)
library(dplyr)
library(ggplot2)
library(magrittr)

# network analysis
library(igraph)

# network viz
library(data.tree)
library(networkD3)

library(threejs)

# col palettes
library(viridis)

# ===============================================================================
# ================================================================================

# ---
# Dependencies
# ---

NODE_SIZE <- 6

### Full Network

df <- read_csv("data/tensorflow_transitive_dependencies.csv") %>%
  filter(!is.na(source__package_name))

df.nodes <- with(df, data.frame(
  id=c(source, target),
  package_name=c(source__package_name, target__package_name)
  )) %>%
  unique()

### color palette

col_palette <- data.frame(
  package_name = levels(df.nodes$package_name),
  # TODO: should use palette generator here
  # color = c(
  #   "#FA8072", "#DC143C", "#FF1493", "#FF5347", "#FFA500", "#FFFF00", 
  #   "#EE82EE", "#ADFF2F", "#008000", "#8FBC8F", "#4682B4", "#4169E1",
  #   "#FFDEAE"
  # )
  color = rainbow(length(levels(df.nodes$package_name)))
)

df.nodes <- right_join(df.nodes, col_palette, by='package_name')
  
net <- graph_from_data_frame(df, vertices=df.nodes)
net <- simplify(net, remove.multiple=T, remove.loops=T)

### Grouped network

df.grouped <- select(df, contains('name')) %>%
  unique() %>%
  set_names(c('source', 'target'))

stack.id <- stack(df, c(source, target)) %>%
  select(values)

stack.package_name <- select(df, contains('name')) %>%
  stack() %>%
  select(values)
  
df.grouped.nodes <- data.frame(stack.package_name, stack.id) %>%
  set_names(c('package_name', 'id')) %>%
  distinct(package_name, .keep_all=T)

df.grouped.nodes <- right_join(df.grouped.nodes, col_palette, by='package_name')

net.grouped <- graph_from_data_frame(df.grouped, vertices=df.grouped.nodes)
net.grouped <- simplify(net.grouped, remove.multiple=T, remove.loops=T)

V(net.grouped)$package_name = V(net.grouped)$name

### DEBUG 

###

# ================================================================================

# ---
# Server logic
# ---

apply_centrality_measure <- function(g, measure) {
  
  if (measure == 'betweenness') {
    V(g)$size <- betweenness(g, directed=T, normalized=F) / 100
  } else if (measure == 'degree') {
    V(g)$size <- degree(g, loops=F) / 10
  } else {  # default
    V(g)$size <- eigen_centrality(g, directed=F)$vector * 10
  }
  
  return(g)
}
  

shinyServer(function(input, output, session) {
  
  IGNORE_WARNING <<- F
  SHINY__EVENT_OBSERVER_OVERRIDE <<- F
  
  warning.grouped_unchecked <- modalDialog(
    title="Warning: `grouped` is unchecked.",
    span("Force graphs may slow down your browser.",
         "It is recommended to use `threejs` backend for ungrouped data.",
         "Proceed on your own responsibility."),
    easyClose=T,
    footer = tagList(
      modalButton("Dismiss."),
      actionButton("ignore_warning", "Proceed anyway.")
    )
  )
  
  # observe usage of ungrouped data when threejs is not used
  observeEvent(c(input$grouped, input$plot_kind), {
    
    if (SHINY__EVENT_OBSERVER_OVERRIDE) {
      
      SHINY__EVENT_OBSERVER_OVERRIDE <<- F
    }
    
    else if (!input$grouped && input$plot_kind != 'threejs') {
      showModal(warning.grouped_unchecked)
      
      updateCheckboxInput(session, 'grouped', value=T)
    }
  })
    
  observeEvent(input$ignore_warning, {
    # user chose his faith
    IGNORE_WARNING <<- T
    SHINY__EVENT_OBSERVER_OVERRIDE <<- T
    
    updateCheckboxInput(session, 'grouped', value=F)
    removeModal()
  }) 
  
  output$network <- renderUI({
    
    if (!input$grouped) {
      
      .graph <- net
      
      .dataframe <- df
      .nodes <- df.nodes
      
    } else {
      
      .graph <- net.grouped
      
      .dataframe <- df.grouped
      .nodes <- df.grouped.nodes
      
    }
    
    .graph <- apply_centrality_measure(.graph, input$centrality)
    
    if (input$plot_kind == 'force' && (input$grouped || IGNORE_WARNING)) {
      
      d3.links <- igraph_to_networkD3(.graph, what='links')
      
      .nodes$size <- V(.graph)$size * input$centrality_impact
      
      display.labels <- if (input$labels) 0.75 else 0
      
      output$force <- renderForceNetwork(
        forceNetwork(Links=d3.links, Source='source', Target='target',
                     Nodes=.nodes, NodeID='package_name', Nodesize='size',
                     Group='package_name',
                     charge=input$charge, zoom=T, bounded=F, opacityNoHover=display.labels)
      )
      
      IGNORE_WARNING <<- F  # ignore the warning only once per approval
      
      forceNetworkOutput('force')
      
    } else if (input$plot_kind == 'diagonal' && (input$grouped || IGNORE_WARNING)) {
      
      # Diagonal Network
      updateCheckboxInput(session, 'labels', value=T)  # default
      
      output$diagonal <- renderDiagonalNetwork(
        diagonalNetwork(ToListExplicit(FromDataFrameNetwork(.dataframe), unname=T))
      )
    
      IGNORE_WARNING <<- F  # ignore the warning only once per approval
      
      diagonalNetworkOutput('diagonal')
      
    } else {  # default
      
      # threejs
        
      V(.graph)$size <- V(.graph)$size * input$centrality_impact
      
      if (input$labels) {
        
        output$threejs <- renderScatterplotThree(
          graphjs(.graph, vertex.label = vertex_attr(.graph, 'package_name'),
                  edge.alpha=0.4) %>%
          points3d(vertices(.), pch=V(.graph)$package_name, size=0.1, color='orange'))
        
      } else {
        
        output$threejs <- renderScatterplotThree(
          graphjs(.graph, vertex.label = vertex_attr(.graph, 'package_name'),
                  edge.alpha=0.4))
      }
      
      scatterplotThreeOutput('threejs')
    }
  })
  
  output$about <- renderText({
    paste0("Sorry, this is yet to be implemented.",
           "\n\nMeanwhile see the slides at https://slides.com/marekcermak/tensorflow-dependencies/live#/")
  })
  
  output$credits <- renderText({
    paste0("Author: Marek Cermak <macermak@redhat.com>",
           "\n\nSource: https://github.com/CermakM/tensorflow_dependency_visualization")
  })
})