#### MODELS ####

model_specs = list(
  classic_qval_and_perseveration = list(
    label  = "RL + kappa",
    params = c(alpha = 0.5, beta = 2.72, kappa = 0.5)
  ),
  classic_qval_and_eval = list(
    label  = "RL + E values",
    params = c(alpha_rl = 0.5, beta_rl = 2.72, alpha_per = 0.5, beta_per = 1.5)
  ),
  qval_and_decay_eval = list(
    label  = "RL + decaying E values",
    params = c(alpha_rl = 0.5, beta_rl = 2.72, alpha_per = 0.5, beta_per = 1.5)
  )
)

param_bounds = list(
  alpha     = c(0, 1),
  alpha_rl  = c(0, 1),
  alpha_per = c(0, 1),
  beta      = c(0.001, NA),
  beta_rl   = c(0.001, NA),
  kappa     = c(NA, NA),
  beta_per  = c(NA, NA)
)

load_model = function(model, root = here::here()) {
  env = new.env(parent = globalenv())
  sys.source(file.path(root, "models", model, paste0(model, ".R")), envir = env)
  env$sim.block
}

#### SIMULATION ####

run_sim = function(sim_fun, params, pwin, Ntrials, seed) {
  cfg = list(
    Narms     = length(pwin),
    Ntrials   = Ntrials,
    expvalues = matrix(rep(pwin, Ntrials), nrow = length(pwin), ncol = Ntrials)
  )
  set.seed(seed)
  out = NULL
  invisible(capture.output(out <- sim_fun(1, params, cfg)))
  out
}

#### TABLE ####

wide_list = function(df, col, prefix) {
  m = do.call(rbind, df[[col]])
  colnames(m) = paste0(prefix, seq_len(ncol(m)))
  as_tibble(m)
}

trial_table = function(df, model, params) {
  narms = length(df$Q_cards[[1]])
  out = tibble(trial = df$trial) |>
    bind_cols(wide_list(df, "Q_cards", "Q"))

  if ("E_cards" %in% names(df)) {
    out = bind_cols(out, wide_list(df, "E_cards", "E"))
  }

  if (model == "classic_qval_and_perseveration") {
    out = out |>
      mutate(
        prev_choice = df$prev_card,
        kappa_bonus = if_else(is.na(prev_choice), NA_real_, unname(params["kappa"]))
      )
  }

  out |>
    bind_cols(wide_list(df, "prob_cards", "p")) |>
    mutate(chosen = df$ch_card, reward = df$reward)
}
