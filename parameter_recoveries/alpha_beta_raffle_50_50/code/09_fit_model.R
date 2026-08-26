# reads: artifacts/simulation_config.rds, artifacts/model_config.rds, artifacts/simulated_data.rds · writes: artifacts/stan_fit.rds

#### LOAD CONFIGURATION ####

simulation_config <- readRDS(file.path(artifacts_dir, "simulation_config.rds"))
list2env(simulation_config, envir = environment())

model_config <- readRDS(file.path(artifacts_dir, "model_config.rds"))
list2env(model_config, envir = environment())

df <- readRDS(file.path(artifacts_dir, "simulated_data.rds"))

#### PREPARE DATA FOR STAN ####

# Create subject index mapping
subject_map <- df |>
  distinct(subject) |>
  arrange(subject) |>
  mutate(subject_id = row_number()) |>
  pull(subject_id, name = subject)

# Prepare stan data list
stan_data <- list(
  n_data       = as.integer(nrow(df)),
  n_subjects   = as.integer(n_distinct(df$subject)),
  n_arms       = as.integer(n_arms),
  n_raffle     = as.integer(n_raffle),
  n_dims       = as.integer(2),
  subject_index = as.integer(subject_map[as.character(df$subject)]),
  ch_card      = as.integer(df$chosen_card),
  ch_key       = as.integer(df$chosen_key),
  reward       = as.integer(df$reward),
  card_left    = as.integer(df$card_left),
  card_right   = as.integer(df$card_right),
  first_trial_in_block = as.integer(df$first_trial_in_block),
  selected_offer = as.integer(df$selected_offer)
)

message("Data prepared for Stan:")
message("  Trials: ", stan_data$n_data)
message("  Subjects: ", stan_data$n_subjects)
message("  Arms: ", stan_data$n_arms)
message("  Raffle: ", stan_data$n_raffle)

#### COMPILE AND FIT STAN MODEL ####

stan_file <- file.path(project_root, "models", fitted_model, paste0(fitted_model, ".stan"))

message("Stan file: ", stan_file)
message("Compiling Stan model...")
mod <- cmdstan_model(stan_file, quiet = FALSE)

message("Stan model compiled successfully. Starting sampling...")

tryCatch({
  fit <- mod$sample(
    data            = stan_data,
    chains          = 2,
    iter_warmup     = 3000,
    iter_sampling   = 2000,
    parallel_chains = 2,
    threads_per_chain = 1,
    refresh         = 100,
    show_messages   = TRUE,
    show_exceptions = TRUE
  )

  message("Sampling completed. Checking output files...")
  message("Output files: ", paste(fit$output_files(), collapse = ", "))

}, error = function(e) {
  message("Error during Stan sampling:")
  message(conditionMessage(e))
  stop(e)
})

#### SAVE FIT OBJECT AND DRAWS ####

# Save the fit object
saveRDS(fit, file.path(artifacts_dir, "stan_fit.rds"))

# Extract and save draws for later use (avoids temporary file issues)
draws_sbj <- as_draws_df(fit$draws(variables = c("alpha_sbj", "beta_sbj")))
draws_pop <- as_draws_df(fit$draws(variables = c("mu_alpha", "mu_beta")))

saveRDS(draws_sbj, file.path(artifacts_dir, "stan_draws_sbj.rds"))
saveRDS(draws_pop, file.path(artifacts_dir, "stan_draws_pop.rds"))

message("Stan model fit complete; diagnostics available in fit object")
