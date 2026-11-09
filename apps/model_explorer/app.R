#### SETUP ####

library(shiny)
library(tidyverse)
library(here)

source(here("apps", "model_explorer", "helpers.R"))

sim_funs   = map(set_names(names(model_specs)), load_model)
sim_trials = 150
model_choices = set_names(names(model_specs), map_chr(model_specs, "label"))

param_input = function(model, name) {
  b = param_bounds[[name]]
  numericInput(
    paste0(model, "__", name), name,
    value = model_specs[[model]]$params[[name]],
    min = b[1], max = b[2], step = 0.05
  )
}

param_panel = function(model) {
  conditionalPanel(
    sprintf("input.model == '%s'", model),
    map(names(model_specs[[model]]$params), \(p) param_input(model, p))
  )
}

#### UI ####

ui = fluidPage(
  tags$head(tags$style(HTML("
    .table { font-size: 13px; }
    .table td, .table th { text-align: right; white-space: nowrap; }
    .well h5 { margin-top: 14px; font-weight: 600; }
  "))),
  titlePanel("Model explorer"),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      selectInput("model", "Model", choices = model_choices),
      h5("Parameters"),
      map(names(model_specs), param_panel),
      h5("Task"),
      fluidRow(
        column(4, numericInput("pwin1", "p(win) 1", 0.5, min = 0, max = 1, step = 0.05)),
        column(4, numericInput("pwin2", "p(win) 2", 0.5, min = 0, max = 1, step = 0.05)),
        column(4, numericInput("pwin3", "p(win) 3", 0.5, min = 0, max = 1, step = 0.05))
      ),
      sliderInput("ntrials", "Trials to show", min = 10, max = 20, value = 15, step = 1),
      fluidRow(
        column(7, numericInput("seed", "Seed", value = 1, step = 1)),
        column(5, actionButton("resample", "Resample", style = "margin-top: 25px; width: 100%;"))
      )
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel("Trial table", br(), tableOutput("trials")),
        tabPanel("WSLS regression", br(), p("Coming soon."))
      )
    )
  )
)

#### SERVER ####

server = function(input, output, session) {

  observeEvent(input$resample, {
    updateNumericInput(session, "seed", value = sample.int(1e6, 1))
  })

  params = reactive({
    names = names(model_specs[[input$model]]$params)
    vals  = map_dbl(names, \(p) input[[paste0(input$model, "__", p)]])
    req(all(!is.na(vals)))
    set_names(vals, names)
  })

  pwin = reactive({
    p = c(input$pwin1, input$pwin2, input$pwin3)
    req(all(!is.na(p)), all(p >= 0 & p <= 1))
    p
  })

  sim_data = reactive({
    req(!is.na(input$seed))
    run_sim(sim_funs[[input$model]], params(), pwin(), sim_trials, input$seed)
  })

  output$trials = renderTable(
    trial_table(sim_data(), input$model, params()) |>
      slice_head(n = input$ntrials) |>
      mutate(across(c(trial, any_of("prev_choice"), chosen, reward), as.integer)),
    digits = 3, na = "", striped = TRUE, hover = TRUE, bordered = TRUE
  )
}

shinyApp(ui, server)
