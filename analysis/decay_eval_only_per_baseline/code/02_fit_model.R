# reads: artifacts/df.rds, models/decay_eval_only/decay_eval_only.stan · writes: artifacts/fit.rds, artifacts/sampler_diagnostics.csv

#### LOAD DATA ####

df <- readRDS(file.path(artifacts_dir, "df.rds"))

# reward is in the Stan data block but unused by the likelihood; this task has no outcomes
stan_data <- list(
  Ndata         = nrow(df),
  Nsubjects     = n_distinct(df$subject),
  Narms         = 3L,
  subject_trial = df$subject,
  ch_card       = df$choice,
  reward        = rep(0L, nrow(df))
)

#### FIT MODEL ####

model <- cmdstan_model(file.path(model_dir, "decay_eval_only.stan"))

fit <- model$sample(
  data            = stan_data,
  chains          = chains,
  parallel_chains = chains,
  iter_warmup     = iter_warmup,
  iter_sampling   = iter_sampling,
  seed            = seed_stan,
  refresh         = 500
)

sampler_diagnostics <- fit$diagnostic_summary() |>
  as_tibble() |>
  mutate(chain = row_number())

print(sampler_diagnostics)

#### SAVE ####

fit$save_object(file.path(artifacts_dir, "fit.rds"))
write_csv(sampler_diagnostics, file.path(artifacts_dir, "sampler_diagnostics.csv"))
