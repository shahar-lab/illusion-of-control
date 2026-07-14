#### FIT STAN MODEL TO SIMULATED DATA ####

df         <- read_rds(file.path(artifacts_dir, "df.rds"))
model_file <- file.path(project_root, "models", "decay_eval_only", "decay_eval_only.stan")

Nsubjects <- max(df$subject)
Narms_fit <- max(df$ch_card)

stan_data <- list(
  Ndata         = nrow(df),
  Nsubjects     = Nsubjects,
  Narms         = Narms_fit,
  subject_trial = df$subject,
  ch_card       = df$ch_card,
  reward        = df$reward
)

model <- cmdstan_model(model_file)

fit <- model$sample(
  data            = stan_data,
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 500,
  iter_sampling   = 500,
  refresh         = 200
)

fit$save_object(file.path(artifacts_dir, "fit.rds"))
cat("Saved: fit.rds\n")

recovered_medians <- tibble(
  subject   = 1:Nsubjects,
  alpha_per = fit$summary(paste0("alpha_per_sbj[", 1:Nsubjects, "]"))$median,
  beta_per  = fit$summary(paste0("beta_per_sbj[",  1:Nsubjects, "]"))$median
)
write_csv(recovered_medians, file.path(artifacts_dir, "recovered_medians.csv"))
cat("Saved: recovered_medians.csv\n")

population_posteriors <- fit$draws(
  variables = c("alpha_per_pop", "beta_per_pop"),
  format    = "df"
)
write_rds(population_posteriors, file.path(artifacts_dir, "population_posteriors.rds"))
cat("Saved: population_posteriors.rds\n")
