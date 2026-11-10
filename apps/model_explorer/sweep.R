#### FAST SIM.BLOCK ####

# same sim.block code; only its output containers are swapped so a sweep keeps
# trial / choice / reward without building one tibble per trial
load_model_fast = function(model, root = here::here()) {
  env = new.env(parent = globalenv())
  sys.source(file.path(root, "models", model, paste0(model, ".R")), envir = env)
  env$tibble    = function(...) { x = list(...); c(x$trial, x$ch_card, x$reward) }
  env$bind_rows = function(l) {
    m = matrix(unlist(l), ncol = 3, byrow = TRUE)
    tibble::tibble(trial = as.integer(m[, 1]), ch_card = as.integer(m[, 2]), reward = m[, 3])
  }
  env$print = function(...) invisible(NULL)
  env$sim.block
}

#### SWEEP SETTINGS ####

sweep_roles = list(
  classic_qval_and_perseveration = list(persev = "kappa",    persev_alpha = NA,          rl = "beta",    rl_alpha = "alpha"),
  classic_qval_and_eval          = list(persev = "beta_per", persev_alpha = "alpha_per", rl = "beta_rl", rl_alpha = "alpha_rl"),
  qval_and_decay_eval            = list(persev = "beta_per", persev_alpha = "alpha_per", rl = "beta_rl", rl_alpha = "alpha_rl")
)

#### SWEEP ####

# one sweep: draw `vary` parameters uniformly in their ranges, keep the rest at `params`
run_sweep = function(sim_fast, params, pwin, Ntrials, n_agents, ranges, seed, progress = NULL) {
  cfg = list(
    Narms     = length(pwin),
    Ntrials   = Ntrials,
    expvalues = matrix(rep(pwin, Ntrials), nrow = length(pwin), ncol = Ntrials)
  )
  set.seed(seed)
  draws = map(ranges, \(r) runif(n_agents, r[1], r[2])) |> as_tibble()

  map(seq_len(n_agents), \(i) {
    p = params
    p[names(ranges)] = unlist(draws[i, ])
    if (!is.null(progress) && i %% 10 == 0) progress(i / n_agents)
    w = fit_wsls(sim_fast(i, p, cfg))
    as_tibble(as.list(p)) |>
      mutate(
        agent      = i,
        b0_linear  = w$coefs$estimate[1], b1_linear  = w$coefs$estimate[2],
        b0_logit   = w$coefs$estimate[3], b1_logit   = w$coefs$estimate[4],
        separation = w$separation
      )
  }) |>
    list_rbind()
}

#### SWEEP PLOTS ####

plot_sweep = function(sw, x, y, colour, current, baseline, xlab, ylab, colour_lab) {
  sw   = sw |> filter(!(separation & str_ends(y, "logit")))
  base = ggplot(sw, aes(.data[[x]], .data[[y]]))
  pts  = if (is.na(colour)) {
    geom_point(alpha = 0.45, size = 1.6, colour = "#2a6fb0")
  } else {
    geom_point(aes(colour = .data[[colour]]), alpha = 0.7, size = 1.6)
  }

  base +
    geom_hline(yintercept = baseline, linetype = "dashed", colour = "grey55") +
    pts +
    geom_smooth(method = "loess", formula = y ~ x, se = FALSE, colour = "black", linewidth = 0.8) +
    (if (!is.na(current$y)) annotate("point", x = current$x, y = current$y, shape = 23, size = 4.5, fill = "#f1c40f", colour = "black")) +
    scale_colour_viridis_c(limits = c(0, 1), option = "plasma", end = 0.9) +
    labs(x = xlab, y = ylab, colour = colour_lab,
         caption = if (is.na(current$y)) "Dashed: no-perseveration baseline. Black: loess." else "Dashed: no-perseveration baseline. Black: loess. Diamond: the agent in the table.") +
    theme_minimal(base_size = 13) +
    theme(legend.position = "right")
}
