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

model <- cmdstan_model(model_file)

fit <- model$sample(
  data            = stan_data,
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 1000,
  iter_sampling   = 1000,
  refresh         = 200
)

fit$save_object(file.path(artifacts_dir, "fit.rds"))
cat("Saved: fit.rds\n")
