rm(list = ls())

#### SETUP ####
library(dplyr)
library(readr)
library(stringr)
library(rstan)

DATA_DIR   <- "../../data/ioc-all-fixed-pilot/task"
MODEL_FILE <- "../../models/qval_and_decay_eval/qval_and_decay_eval.stan"
DRAWS_DIR  <- "bayesian_draws_qde"

dir.create(DRAWS_DIR, showWarnings = FALSE)

KEY_TO_CARD <- c(arrowleft = 1L, arrowup = 2L, arrowright = 3L)

#### LOAD DATA ####
files <- sort(list.files(DATA_DIR, pattern = "^ioc-all_.*_SESSION.*\\.csv$", full.names = TRUE))

df <- files |>
  lapply(function(f) {
    pid <- str_extract(f, "[a-f0-9]{24}")
    read_csv(f, col_types = cols(.default = "c")) |> mutate(participant = pid)
  }) |>
  bind_rows()

df <- df |>
  filter(task == "gambling_choice", block_number != "training", as.logical(is_choice_valid)) |>
  mutate(
    block_number = as.integer(block_number),
    trial_number = as.integer(trial_number),
    reward       = as.integer(reward),
    ch_card      = KEY_TO_CARD[choice_key]
  ) |>
  arrange(participant, block_number, trial_number)

participants <- sort(unique(df$participant))
pid_to_idx   <- setNames(seq_along(participants), participants)

df <- df |>
  mutate(subject_trial = pid_to_idx[participant]) |>
  group_by(participant) |>
  mutate(first_trial = as.integer(row_number() == 1)) |>
  ungroup()

Nsubjects <- length(participants)
Ndata     <- nrow(df)

cat("Total trials:", Ndata, "\n")
cat("Subjects:    ", Nsubjects, "\n")

participant_map <- tibble(
  participant     = participants,
  participant_idx = pid_to_idx[participants]
)
write_csv(participant_map, file.path(DRAWS_DIR, "participant_map.csv"))

stan_data <- list(
  Ndata         = Ndata,
  Nsubjects     = Nsubjects,
  Narms         = 3L,
  subject_trial = df$subject_trial,
  ch_card       = df$ch_card,
  reward        = df$reward
)

#### FIT MODEL ####
fit <- stan(
  file    = MODEL_FILE,
  data    = stan_data,
  chains  = 4,
  iter    = 2000,
  warmup  = 1000,
  seed    = 1,
  refresh = 200
)

print(fit, pars = c("alpha_rl_pop", "alpha_per_pop", "beta_rl_pop", "beta_per_pop"))

draws <- extract(fit)

#### SAVE GROUP DRAWS ####
draws_group <- tibble(
  alpha_rl_pop  = as.numeric(draws$alpha_rl_pop),
  alpha_per_pop = as.numeric(draws$alpha_per_pop),
  beta_rl_pop   = as.numeric(draws$beta_rl_pop),
  beta_per_pop  = as.numeric(draws$beta_per_pop)
)
write_csv(draws_group, file.path(DRAWS_DIR, "posterior_draws_group.csv"))

#### SAVE SUBJECT DRAWS ####
draws_subject_list <- list()
param_names <- c("alpha_rl", "alpha_per", "beta_rl", "beta_per")
sbj_arrays  <- list(
  alpha_rl  = draws$alpha_rl_sbj,
  alpha_per = draws$alpha_per_sbj,
  beta_rl   = draws$beta_rl_sbj,
  beta_per  = draws$beta_per_sbj
)

for (pname in param_names) {
  arr <- sbj_arrays[[pname]]
  for (s in seq_len(Nsubjects)) {
    draws_s <- arr[, s]
    draws_subject_list[[length(draws_subject_list) + 1]] <- tibble(
      participant = participants[s],
      param       = paste0(pname, "_qde"),
      median      = median(draws_s),
      lo90        = unname(quantile(draws_s, 0.05)),
      hi90        = unname(quantile(draws_s, 0.95))
    )
  }
}

draws_subject <- bind_rows(draws_subject_list)
write_csv(draws_subject, file.path(DRAWS_DIR, "posterior_draws_subject.csv"))

cat("\nSaved group draws   ->", file.path(DRAWS_DIR, "posterior_draws_group.csv"), "\n")
cat("Saved subject draws  ->", file.path(DRAWS_DIR, "posterior_draws_subject.csv"), "\n")
cat("Saved participant map->", file.path(DRAWS_DIR, "participant_map.csv"), "\n")
