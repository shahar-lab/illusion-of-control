#### FIT STAN MODEL TO SIMULATED DATA ####
# reads: artifacts/df.rds, cfg.rds · writes: artifacts/fit.rds, recovered_medians.csv, population_posteriors.rds

df  <- read_rds(file.path(artifacts_dir, "df.rds"))
cfg <- read_rds(file.path(artifacts_dir, "cfg.rds"))

model_file <- file.path(project_root, "models", "classic_qval_raffle", "classic_qval_raffle.stan")

Nsubjects    <- max(df$subject)
Narms        <- max(df$ch_card)
Nraffle      <- cfg$Nraffle
offered_arms_mat <- do.call(rbind, df$offered_arms)

stan_data <- list(
  Ndata         = nrow(df),
  Nsubjects     = Nsubjects,
  Narms         = Narms,
  Nraffle       = Nraffle,
  subject_trial = df$subject,
  ch_card       = df$ch_card,
  reward        = df$reward,
  offered_arms  = offered_arms_mat
)

model <- cmdstan_model(model_file)

fit <- model$sample(
  data            = stan_data,
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 2000,
  iter_sampling   = 3000,
  refresh         = 200
)

fit$save_object(file.path(artifacts_dir, "fit.rds"))
cat("Saved: fit.rds\n")

recovered_medians <- tibble(
  subject  = 1:Nsubjects,
  alpha_rl = fit$summary(paste0("alpha_rl_sbj[", 1:Nsubjects, "]"))$median,
  beta_rl  = fit$summary(paste0("beta_rl_sbj[",  1:Nsubjects, "]"))$median
)
write_csv(recovered_medians, file.path(artifacts_dir, "recovered_medians.csv"))
cat("Saved: recovered_medians.csv\n")

population_posteriors <- fit$draws(
  variables = c("alpha_rl_pop", "beta_rl_pop"),
  format    = "df"
)
write_rds(population_posteriors, file.path(artifacts_dir, "population_posteriors.rds"))
cat("Saved: population_posteriors.rds\n")
