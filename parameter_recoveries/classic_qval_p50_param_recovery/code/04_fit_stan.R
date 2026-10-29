# reads: artifacts/df.rds · writes: artifacts/fit.rds, recovered_summary.csv, posterior_cor.csv, population_posteriors.rds

#### FIT STAN MODEL TO SIMULATED DATA ####

df         <- read_rds(file.path(artifacts_dir, "df.rds"))
model_file <- file.path(project_root, "models", model_name, paste0(model_name, ".stan"))

Nsubjects_fit <- max(df$subject)

stan_data <- list(
  Ndata         = nrow(df),
  Nsubjects     = Nsubjects_fit,
  Narms         = max(df$ch_card),
  subject_trial = df$subject,
  ch_card       = df$ch_card,
  reward        = df$reward
)

model <- cmdstan_model(model_file)

start_time <- Sys.time()
fit <- model$sample(
  data            = stan_data,
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = iter_warmup,
  iter_sampling   = iter_sampling,
  seed            = seed_stan,
  refresh         = 500
)
runtime_min <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))

fit$save_object(file.path(artifacts_dir, "fit.rds"))
write_rds(runtime_min, file.path(artifacts_dir, "runtime_min.rds"))


#### SUBJECT-LEVEL SUMMARIES ####

recovered_summary <- fit$summary(
  variables = c("alpha_sbj", "beta_sbj"),
  "median", "sd", ~ quantile(.x, probs = c(0.05, 0.95))
) |>
  rename(q5 = `5%`, q95 = `95%`) |>
  mutate(
    param   = sub("_sbj.*", "", variable),
    subject = as.integer(gsub("\\D", "", variable))
  ) |>
  select(subject, param, median, sd, q5, q95)

write_csv(recovered_summary, file.path(artifacts_dir, "recovered_summary.csv"))

# Per-subject correlation between alpha and beta across posterior draws
subject_draws <- fit$draws(variables = c("alpha_sbj", "beta_sbj"), format = "draws_matrix")

posterior_cor <- tibble(
  subject         = 1:Nsubjects_fit,
  alpha_beta_cor  = sapply(1:Nsubjects_fit, function(s) {
    cor(subject_draws[, paste0("alpha_sbj[", s, "]")], subject_draws[, paste0("beta_sbj[", s, "]")])
  })
)

write_csv(posterior_cor, file.path(artifacts_dir, "posterior_cor.csv"))


#### POPULATION-LEVEL DRAWS ####

population_posteriors <- fit$draws(
  variables = c("mu_alpha", "mu_beta", "sigma_alpha", "sigma_beta", "alpha_pop", "beta_pop"),
  format    = "df"
)

write_rds(population_posteriors, file.path(artifacts_dir, "population_posteriors.rds"))

cat("Fit finished in", round(runtime_min, 1), "minutes\n")
