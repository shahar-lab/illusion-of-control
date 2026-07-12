#### FIT STAN MODEL TO SIMULATED DATA ####

sim_data  <- read_rds(file.path(artifacts_dir, "sim_data.rds"))
model_file <- file.path(project_root, "models", "classic_qval_and_eval", "classic_qval_and_eval.stan")

Nsubjects <- max(sim_data$subject)
Narms_fit <- max(sim_data$ch_card)

stan_data <- list(
  Ndata         = nrow(sim_data),
  Nsubjects     = Nsubjects,
  Narms         = Narms_fit,
  subject_trial = sim_data$subject,
  ch_card       = sim_data$ch_card,
  reward        = sim_data$reward
)

# Safe initial values: all raw parameters at 0 → subject params at inv_logit(0) = 0.5
# or exp(0) = 1, both well inside the support, guaranteeing finite log-likelihoods.
init_fn <- function() list(
  mu_alpha_rl     = 0,   mu_alpha_per  = 0,
  mu_beta_rl      = 0,   mu_beta_per   = 0,
  sigma_alpha_rl  = 0.5, sigma_alpha_per = 0.5,
  sigma_beta_rl   = 0.5, sigma_beta_per  = 0.5,
  alpha_rl_raw    = rep(0, Nsubjects),
  alpha_per_raw   = rep(0, Nsubjects),
  beta_rl_raw     = rep(0, Nsubjects),
  beta_per_raw    = rep(0, Nsubjects)
)

model <- cmdstan_model(model_file)

fit <- model$sample(
  data            = stan_data,
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 1000,
  iter_sampling   = 1000,
  adapt_delta     = 0.95,
  init            = init_fn,
  refresh         = 200
)

fit$save_object(file.path(artifacts_dir, "fit.rds"))
cat("Saved: fit.rds\n")
