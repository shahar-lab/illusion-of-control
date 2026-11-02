# reads: artifacts/df.rds · writes: artifacts/fit.rds, recovered_summary.csv, posterior_cor.csv, population_posteriors.rds

#### FIT STAN MODEL TO SIMULATED DATA ####

df         <- read_rds(file.path(artifacts_dir, "df.rds"))
model_file <- file.path(project_root, "models", model_name, paste0(model_name, ".stan"))

Nsubjects_fit <- max(df$subject)
param_names   <- population_params$param
sbj_vars      <- paste0(param_names, "_sbj")

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
  refresh         = 200
)
runtime_min <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))

fit$save_object(file.path(artifacts_dir, "fit.rds"))
write_rds(runtime_min, file.path(artifacts_dir, "runtime_min.rds"))


#### SUBJECT-LEVEL SUMMARIES ####

recovered_summary <- fit$summary(
  variables = sbj_vars,
  "median", "sd", ~ quantile(.x, probs = c(0.05, 0.95))
) |>
  rename(q5 = `5%`, q95 = `95%`) |>
  mutate(
    param   = sub("_sbj.*", "", variable),
    subject = as.integer(gsub(".*\\[|\\]", "", variable))
  ) |>
  select(subject, param, median, sd, q5, q95)

write_csv(recovered_summary, file.path(artifacts_dir, "recovered_summary.csv"))

# Per-subject correlation across posterior draws, for every pair of parameters
subject_draws <- fit$draws(variables = sbj_vars, format = "draws_matrix")
param_pairs   <- combn(param_names, 2, simplify = FALSE)

posterior_cor <- bind_rows(lapply(param_pairs, function(params) {
  pair_cor <- sapply(1:Nsubjects_fit, function(s) {
    cor(subject_draws[, paste0(params[1], "_sbj[", s, "]")], subject_draws[, paste0(params[2], "_sbj[", s, "]")])
  })
  tibble(subject = 1:Nsubjects_fit, pair = paste(params, collapse = "_"), cor = pair_cor)
}))

write_csv(posterior_cor, file.path(artifacts_dir, "posterior_cor.csv"))


#### POPULATION-LEVEL DRAWS ####

population_posteriors <- fit$draws(
  variables = c(paste0("mu_", param_names), paste0("sigma_", param_names), paste0(param_names, "_pop")),
  format    = "df"
)

write_rds(population_posteriors, file.path(artifacts_dir, "population_posteriors.rds"))

cat("Fit finished in", round(runtime_min, 1), "minutes\n")
