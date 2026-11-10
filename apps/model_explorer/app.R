#### SETUP ####

library(shiny)
library(tidyverse)
library(here)

source(here("apps", "model_explorer", "helpers.R"))
source(here("apps", "model_explorer", "wsls.R"))
source(here("apps", "model_explorer", "sweep.R"))

sim_funs   = map(set_names(names(model_specs)), load_model)
sim_trials = 150
sim_fast   = map(set_names(names(model_specs)), load_model_fast)
alpha_range = c(0.02, 0.98)

sec_per_agent = local({
  m   = "qval_and_decay_eval"
  run = \(n) run_sweep(sim_fast[[m]], model_specs[[m]]$params, rep(0.5, 3), sim_trials, n, list(alpha_rl = alpha_range), 1)
  run(5)
  system.time(run(30))[["elapsed"]] / 30
})

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
    .sweep { border-top: 1px solid #ddd; margin-top: 18px; padding-top: 10px; }
    .eta { font-size: 13px; color: #444; margin-top: 4px; }
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
      ),
      div(
        class = "sweep",
        h4("Parameter sweep: b0 vs perseveration parameter, b1 vs beta_rl"),
        p(class = "note", paste(
          "Each agent is a fresh 150-trial sim.block() run of the sweep model, with that model's sidebar parameters and p(win);",
          "only the swept parameters are redrawn uniformly from the ranges below. Nothing is saved."
        )),
        fluidRow(
          column(3,
            sliderInput("n_agents", "Agents per sweep", min = 20, max = 600, value = 140, step = 20),
            div(class = "eta", textOutput("eta", inline = TRUE))
          ),
          column(3,
            sliderInput("persev_range", "Perseveration parameter range (kappa / beta_per)", min = -5, max = 5, value = c(-3, 3), step = 0.5),
            sliderInput("rl_range", "beta / beta_rl range", min = 0, max = 12, value = c(0.1, 8), step = 0.1)
          ),
          column(3,
            selectInput("sweep_model", "Sweep model", choices = model_choices),
            div(class = "eta", textOutput("sweep_fixed", inline = TRUE)),
            radioButtons("sweep_scale", "Regression", c("linear", "logistic"), inline = TRUE),
            conditionalPanel(
              "input.sweep_model != 'classic_qval_and_perseveration'",
              radioButtons("b0_x", "b0 plotted against", c("beta_per" = "beta_per", "beta_per x alpha_per" = "persev_x_alpha"), inline = TRUE)
            )
          ),
          column(3,
            actionButton("run_sweep", "Run sweep", class = "btn-primary", style = "margin-top: 25px; width: 100%;"),
            div(class = "eta", textOutput("sweep_info", inline = TRUE))
          )
        ),
        fluidRow(
          column(6, plotOutput("sweep_b0", height = "380px")),
          column(6, plotOutput("sweep_b1", height = "380px"))
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

  model_params = function(model) {
    names = names(model_specs[[model]]$params)
    vals  = map_dbl(names, \(p) input[[paste0(model, "__", p)]] %||% NA_real_)
    req(all(!is.na(vals)))
    set_names(vals, names)
  }

  params = reactive(model_params(input$model))

  observeEvent(input$model, updateSelectInput(session, "sweep_model", selected = input$model))

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

  output$eta = renderText(sprintf(
    "%d agents in total (2 sweeps), about %.0f s on this machine",
    2 * input$n_agents, ceiling(2 * input$n_agents * sec_per_agent * 1.1 + 1)
  ))

  sweep = eventReactive(input$run_sweep, {
    model  = input$sweep_model
    roles  = sweep_roles[[model]]
    params = model_params(model)
    t0 = Sys.time()

    withProgress(message = "Running sweep", value = 0, {
      b0_ranges = list(input$persev_range)
      names(b0_ranges) = roles$persev
      if (!is.na(roles$persev_alpha)) b0_ranges[[roles$persev_alpha]] = alpha_range
      b0 = run_sweep(sim_fast[[model]], params, pwin(), sim_trials, input$n_agents, b0_ranges,
                     input$seed + 1, \(f) setProgress(f / 2, detail = "b0 sweep"))

      b1_ranges = list(input$rl_range, alpha_range)
      names(b1_ranges) = c(roles$rl, roles$rl_alpha)
      b1 = run_sweep(sim_fast[[model]], params, pwin(), sim_trials, input$n_agents, b1_ranges,
                     input$seed + 2, \(f) setProgress(0.5 + f / 2, detail = "b1 sweep"))
    })

    if (!is.na(roles$persev_alpha)) {
      b0 = b0 |> mutate(persev_x_alpha = .data[[roles$persev]] * .data[[roles$persev_alpha]])
    }

    list(
      model = model, roles = roles, params = params, b0 = b0, b1 = b1, coefs = if (model == input$model) wsls()$coefs else NULL,
      secs  = as.numeric(difftime(Sys.time(), t0, units = "secs"))
    )
  })

  output$sweep_info = renderText({
    sw = sweep()
    nsep = sum(sw$b0$separation) + sum(sw$b1$separation)
    sprintf("%s: %d agents in %.1f s. %d agent(s) with stay rate 0 or 1 dropped from logistic plots.",
            model_specs[[sw$model]]$label, nrow(sw$b0) + nrow(sw$b1), sw$secs, nsep)
  })

  output$sweep_fixed = renderText({
    model = input$sweep_model
    roles = sweep_roles[[model]]
    p     = model_params(model)
    held  = \(swept) {
      h = p[!names(p) %in% swept]
      paste(names(h), "=", h, collapse = ", ")
    }
    sprintf("b0 sweep holds %s; b1 sweep holds %s (sidebar values for this model).",
            held(c(roles$persev, roles$persev_alpha)), held(c(roles$rl, roles$rl_alpha)))
  })

  current_coef = function(sw, term) {
    if (is.null(sw$coefs)) return(NA_real_)
    sw$coefs |> filter(model == input$sweep_scale, .data$term == !!term) |> pull(estimate)
  }

  output$sweep_b0 = renderPlot({
    sw    = sweep()
    roles = sw$roles
    y     = if (input$sweep_scale == "linear") "b0_linear" else "b0_logit"
    x     = if (!is.na(roles$persev_alpha) && input$b0_x == "persev_x_alpha") "persev_x_alpha" else roles$persev
    cur_x = if (x == "persev_x_alpha") sw$params[[roles$persev]] * sw$params[[roles$persev_alpha]] else sw$params[[roles$persev]]
    plot_sweep(
      sw$b0, x, y,
      colour     = if (is.na(roles$persev_alpha)) NA else roles$persev_alpha,
      current    = list(x = cur_x, y = current_coef(sw, "b0")),
      baseline   = if (input$sweep_scale == "linear") 1 / 3 else qlogis(1 / 3),
      xlab       = if (x == "persev_x_alpha") paste(roles$persev, "x", roles$persev_alpha) else roles$persev,
      ylab       = paste0("b0 (", input$sweep_scale, ")"),
      colour_lab = roles$persev_alpha
    ) + ggtitle("Perseveration effect b0")
  })

  output$sweep_b1 = renderPlot({
    sw    = sweep()
    roles = sw$roles
    y     = if (input$sweep_scale == "linear") "b1_linear" else "b1_logit"
    plot_sweep(
      sw$b1, roles$rl, y,
      colour     = roles$rl_alpha,
      current    = list(x = sw$params[[roles$rl]], y = current_coef(sw, "b1")),
      baseline   = 0,
      xlab       = roles$rl,
      ylab       = paste0("b1 (", input$sweep_scale, ")"),
      colour_lab = roles$rl_alpha
    ) + ggtitle("Win-stay/lose-shift effect b1")
  })
}

shinyApp(ui, server)
