#### SETUP ####

library(shiny)
library(tidyverse)
library(here)

source(here("apps", "model_explorer", "helpers.R"))
source(here("apps", "model_explorer", "wsls.R"))

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
    .table { font-size: 12px; margin-bottom: 8px; }
    .scroll-x { overflow-x: auto; }
    .well input.form-control { padding: 6px 8px; }
    .table td, .table th { text-align: right; white-space: nowrap; }
    .well h5 { margin-top: 14px; font-weight: 600; }
    h4 { font-weight: 600; margin-top: 4px; }
    .note { color: #666; font-size: 12px; }
    .warn { color: #b03a2e; font-size: 13px; }
  "))),
  titlePanel("Model explorer"),
  sidebarLayout(
    sidebarPanel(
      width = 2,
      selectInput("model", "Model", choices = model_choices),
      h5("Parameters"),
      map(names(model_specs), param_panel),
      h5("p(win) per arm"),
      fluidRow(
        column(4, style = "padding-right: 4px;", numericInput("pwin1", "arm 1", 0.5, min = 0, max = 1, step = 0.05)),
        column(4, style = "padding: 0 2px;", numericInput("pwin2", "arm 2", 0.5, min = 0, max = 1, step = 0.05)),
        column(4, style = "padding-left: 4px;", numericInput("pwin3", "arm 3", 0.5, min = 0, max = 1, step = 0.05))
      ),
      sliderInput("ntrials", "Trials to show", min = 10, max = 20, value = 15, step = 1),
      numericInput("seed", "Seed", value = 1, step = 1),
      actionButton("resample", "Resample", style = "width: 100%;")
    ),
    mainPanel(
      width = 10,
      fluidRow(
        column(
          7,
          h4("Trial table"),
          div(class = "scroll-x", tableOutput("trials"))
        ),
        column(
          5,
          h4(textOutput("wsls_title", inline = TRUE)),
          p(class = "note", "stay_t ~ b0 + b1 * reward_{t-1}, reward coded -0.5 / +0.5, same agent as the table."),
          plotOutput("wsls_plot", height = "330px"),
          uiOutput("wsls_warn"),
          div(class = "scroll-x", tableOutput("wsls_coefs")),
          plotOutput("choice_plot", height = "190px")
        )
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
    digits = 3, na = "", striped = TRUE, hover = TRUE, bordered = TRUE, spacing = "xs"
  )

  wsls = reactive(fit_wsls(sim_data()))

  output$wsls_title = renderText(sprintf("WSLS regression (all %d trials)", sim_trials))

  output$wsls_plot = renderPlot(plot_wsls(wsls()))

  output$wsls_warn = renderUI({
    if (wsls()$separation) {
      p(class = "warn", "Stay rate is 0 or 1 after wins or losses: logistic estimates are unstable (separation).")
    }
  })

  output$wsls_coefs = renderTable(
    wsls()$coefs |>
      transmute(
        model, term,
        estimate, se,
        baseline,
        `est - baseline` = vs_baseline
      ) |>
      bind_rows(
        wsls()$rates |>
          transmute(model = "observed", term = if_else(rew_prev < 0, "P(stay | loss)", "P(stay | win)"),
                    estimate = stay, se = sqrt(stay * (1 - stay) / n))
      ),
    digits = 3, na = "", striped = TRUE, bordered = TRUE, spacing = "xs"
  )

  output$choice_plot = renderPlot(plot_choices(sim_data(), input$ntrials))
}

shinyApp(ui, server)
