rm(list = ls())

#### SETUP ####
library(dplyr)
library(readr)
library(stringr)
library(rstan)

DATA_DIR   <- "../../data/ioc-all-fixed-pilot/task"
MODEL_FILE <- "../../models/classic_qval_and_unchosen_eval_zero/classic_qval_and_unchosen_eval_zero.stan"
DRAWS_DIR  <- "bayesian_draws_classic_qval_and_unchosen_eval_zero"

dir.create(DRAWS_DIR, showWarnings = FALSE)

KEY_TO_CARD <- c(arrowleft = 1L, arrowup = 2L, arrowright = 3L)

MISUNDERSTOOD <- c(
  "67dae998d8f2cfb8a8e3bf03",
  "6a087d170d5521dd2055e045",
  "6a0ac6bc5fb56e6d7f8e6569"
)
FELT_DIFFERENT <- c(
  "677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
  "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2",
  "5c41f9ce4fe4f800016dfaac", "651d64e4756ee3358eeb981f",
  "6982544679288685d8a0199f", "69a7048762f2aacbfb3c2f02",
  "69de2b262f16bdb2c0122847", "6a01c4c8248651c0157c76c5"
)

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
    choice       = KEY_TO_CARD[choice_key]
  ) |>
  arrange(participant, block_number, trial_number)

participants <- sort(unique(df$participant))
pid_to_idx   <- setNames(seq_along(participants), participants)

df <- df |>
  mutate(subject_trial = pid_to_idx[participant])

Nsubjects <- length(participants)
Ndata     <- nrow(df)

cat("Total trials:", Ndata, "\n")
cat("Subjects:    ", Nsubjects, "\n")

participant_map <- tibble(
  participant        = participants,
  participant_idx    = pid_to_idx[participants],
  understood_eq_felt = !(participants %in% MISUNDERSTOOD) & !(participants %in% FELT_DIFFERENT)
)
write_csv(participant_map, file.path(DRAWS_DIR, "participant_map.csv"))

stan_data <- list(
  Ndata         = Ndata,
  Nsubjects     = Nsubjects,
  Narms         = 3L,
  subject_trial = df$subject_trial,
  ch_card       = df$choice,
  reward        = df$reward
)

#### FIT MODEL ####
fit <- stan(
  file    = MODEL_FILE,
  data    = stan_data,
  chains  = 4,
  iter    = 2000,
  warmup  = 1000,
  cores   = 1,
  seed    = 1,
  refresh = 200
)

print(fit, pars = c("alpha_rl_pop", "delta_pop", "beta_rl_pop", "beta_per_pop"))

saveRDS(fit, file.path(DRAWS_DIR, "fit_classic_qval_and_unchosen_eval_zero.rds"))

draws <- rstan::extract(fit)

#### SAVE GROUP DRAWS ####
draws_group <- tibble(
  alpha_rl_pop = as.numeric(draws$alpha_rl_pop),
  delta_pop    = as.numeric(draws$delta_pop),
  beta_rl_pop  = as.numeric(draws$beta_rl_pop),
  beta_per_pop = as.numeric(draws$beta_per_pop)
)
write_csv(draws_group, file.path(DRAWS_DIR, "posterior_draws_group.csv"))

#### SAVE SUBJECT DRAWS ####
sbj_param_map <- list(
  alpha_rl  = draws$alpha_rl_sbj,
  delta     = draws$delta_sbj,
  beta_rl   = draws$beta_rl_sbj,
  beta_per  = draws$beta_per_sbj
)

draws_subject <- lapply(names(sbj_param_map), function(pname) {
  arr <- sbj_param_map[[pname]]
  lapply(seq_len(Nsubjects), function(s) {
    draws_s <- arr[, s]
    tibble(
      participant        = participants[s],
      understood_eq_felt = participant_map$understood_eq_felt[s],
      param              = pname,
      median             = median(draws_s),
      lo90               = unname(quantile(draws_s, 0.05)),
      hi90               = unname(quantile(draws_s, 0.95))
    )
  }) |> bind_rows()
}) |> bind_rows()

write_csv(draws_subject, file.path(DRAWS_DIR, "posterior_draws_subject.csv"))

cat("\nSaved fit object     ->", file.path(DRAWS_DIR, "fit_classic_qval_and_unchosen_eval_zero.rds"), "\n")
cat("Saved group draws    ->", file.path(DRAWS_DIR, "posterior_draws_group.csv"), "\n")
cat("Saved subject draws  ->", file.path(DRAWS_DIR, "posterior_draws_subject.csv"), "\n")
