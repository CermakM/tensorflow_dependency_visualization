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

shinyServer(function(input, output) {
  
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
    
    if (input$plot_kind == 'force') {
      
      d3.links <- igraph_to_networkD3(.graph, what='links')
      
      output$force <- renderForceNetwork(
        forceNetwork(Links=d3.links, Source='source', Target='target',
                     Nodes=.nodes, NodeID='package_name', #Nodesize='size',
                     Group='package_name', zoom=T, bounded=F)
      )
      
      forceNetworkOutput('force')
      
    } else if (input$plot_kind == 'diagonal') {
      
      # Diagonal Network
      
      output$diagonal <- renderDiagonalNetwork(
        diagonalNetwork(ToListExplicit(FromDataFrameNetwork(.dataframe), unname=T))
      )
      
      diagonalNetworkOutput('diagonal')
      
    } else {  # default
      
      # threejs
      
      output$threejs <- renderScatterplotThree(
        graphjs(.graph, vertex.label = vertex_attr(.graph, 'package_name'),
                edge.alpha=0.4)
      )
      
      scatterplotThreeOutput('threejs')
    }
    
  })
})