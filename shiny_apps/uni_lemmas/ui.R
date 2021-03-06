library(shiny)
library(shinythemes)
library(shinyBS)
library(markdown)


shinyUI(fluidPage(

  theme = shinytheme("spacelab"),

  br(),
  bsCollapse(id = "doc", open = "title",
             bsCollapsePanel(title = h3("Cross-Linguistic Trajectories"),
                             includeMarkdown("docs/description.md"),
                             value = "title",
                             style = "default")),

  sidebarLayout(
    sidebarPanel(
      width = 3,

      conditionalPanel(
        condition = "output.loaded != 1",
        h4("Loading...")
      ),

      conditionalPanel(
        condition = "output.loaded == 1",
        uiOutput("uni_lemma"),
        width = 3)),

    mainPanel(
      width = 9,
      tags$style(type = "text/css",
                 ".shiny-output-error { visibility: hidden; }",
                 ".shiny-output-error:before { visibility: hidden; }"),
      tabsetPanel(
        tabPanel("Plot",
                 br(),
                 conditionalPanel(
                   condition = "output.loaded == 1",
                   plotOutput("crosslinguistic"),
                   br(),
                   downloadButton("download_plot", "Download Plot",
                                  class = "btn-default btn-xs")
                 )
        ),
        tabPanel("Table",
                 br(),
                 downloadButton("download_table", "Download Table",
                                class = "btn-default btn-xs"),
                 br(), br(),
                 tableOutput("table"))
      )
    )
  )
))
