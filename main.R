library(readxl)
library(dplyr)
library(networkD3)
library(htmltools)
library(RColorBrewer)

# I'm using the original Excel workbook, given with the assignment, as the input
file_path <- "interactions_data.xlsx"
primary_characters <- read_excel(file_path, sheet = "primary characters")
conversational_lines <- read_excel(file_path, sheet = "conversational lines")

# Prepare nodes
nodes <- primary_characters %>%
  select(name) %>%
  mutate(
    id = row_number() - 1,
    size = 10
  ) %>%
  as.data.frame()

# Prepare edges
edges <- conversational_lines %>%
  rename(
    source_name = `speaking character`,
    target_name = `character spoken to`,
    value = `number of lines spoken directly to`
  ) %>%
  left_join(nodes, by = c("source_name" = "name")) %>%
  rename(source = id) %>%
  left_join(nodes, by = c("target_name" = "name")) %>%
  rename(target = id) %>%
  select(source, target, value) %>%
  as.data.frame()

# Color palette for nodes
n_nodes <- nrow(nodes)
node_colours <- colorRampPalette(brewer.pal(8, "Dark2"))(n_nodes)
node_colours_js_array <- paste0("['", paste(node_colours, collapse = "', '"), "']")

# Force directed network
network <- forceNetwork(
  Links = edges,
  Nodes = nodes,
  Source = "source",
  Target = "target",
  Value = "value",
  NodeID = "name",
  opacity = 0.9,
  zoom = TRUE,
  fontSize = 14,
  Nodesize = "size",
  linkDistance = 100,
  charge = -300,
  linkColour = "#CCCCCC", # Light gray
  colourScale = JS(paste0("d3.scaleOrdinal().range(", node_colours_js_array, ")")),
  Group = "id",
  opacityNoHover = 0.7
)

# Adjust text color and node borders
network$x$jsHooks$render <- htmlwidgets::JS("
  function(el) {
    d3.selectAll('.node circle')
      .style('stroke', '#333333')
      .style('stroke-width', '1.5px');
    d3.selectAll('.node text')
      .style('fill', '#000000')
      .style('font-weight', 'bold');
  }
")

# Adjacency matrix for chord diagram
character_names <- nodes$name
adj_matrix <- matrix(
  0,
  nrow = length(character_names),
  ncol = length(character_names),
  dimnames = list(character_names, character_names)
)
for (i in 1:nrow(edges)) {
  source <- character_names[edges$source[i] + 1]
  target <- character_names[edges$target[i] + 1]
  adj_matrix[source, target] <- edges$value[i]
  adj_matrix[target, source] <- edges$value[i]
}

# Color palette for chords
chords <- sum(adj_matrix[upper.tri(adj_matrix)] > 0)
chord_colours <- colorRampPalette(brewer.pal(12, "Set3"))(chords)
chord_colours_js_array <- paste0("['", paste(chord_colours, collapse = "', '"), "']")

# Chord diagram
chord <- chordNetwork(
  adj_matrix,
  labels = character_names,
  width = 500,
  height = 500
)

# Color chords
chord$x$jsHooks$render <- htmlwidgets::JS(paste0("
  function(el) {
    var colors = d3.scaleOrdinal().range(", chord_colours_js_array, ");
    d3.select(el).selectAll('.chord path')
      .style('fill', function(d, i) {
        return colors(i);
      });
  }
"))

visualizations <- tagList(
  tags$div(
    style = "display: flex; flex-direction: column; align-items: center; padding: 20px; gap: 10px;",
    tags$h1("Network Visualization in R", style = "text-align: center;"),
    tags$h3("Misagh Soltani", style = "text-align: center; color: #555555;"),
    tags$h2("Force Directed Network: Character Interactions", style = "text-align: center; margin-top: 20px;"),
    tags$div(
      style = "width: 100%; height: 45vh; min-height: 300px; display: flex; justify-content: center; align-items: center;",
      network
    ),
    tags$h2("Chord Network: Character Interactions Intensity", style = "text-align: center; margin-top: 20px;"),
    tags$div(
      style = "width: 100%; height: 45vh; min-height: 300px; display: flex; justify-content: center; align-items: center;",
      chord
    )
  )
)

# Save as a HTML file, please check the HTML output for the result
htmltools::save_html(visualizations, "index.html")
