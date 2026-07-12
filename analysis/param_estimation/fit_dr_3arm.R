rm(list = ls())

#### SETUP ####
library(dplyr)
library(readr)
library(stringr)
library(rstan)

DATA_DIR   <- "../../data/ioc-all-fixed-pilot/task"
MODEL_FILE <- "../../models/dr_3arm/dr_3arm.stan"
DRAWS_DIR  <- "bayesian_draws_dr"

dir.create(DRAWS_DIR, showWarnings = FALSE)

KEY_TO_CARD <- c(arrowleft = 1L, arrowup = 2L, arrowright = 3L)

MISUNDERSTOOD  <- "67dae998d8f2cfb8a8e3bf03"
FELT_DIFFERENT <- c(
  "677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
  "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2"
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
    choice       = KEY_TO_CARD[choice_key]
  ) |>
  arrange(participant, block_number, trial_number)

participants <- sort(unique(df$participant))
pid_to_idx   <- setNames(seq_along(participants), participants)

df <- df |>
  mutate(subject_trial = pid_to_idx[participant]) |>
  group_by(participant, block_number) |>
  mutate(first_trial_in_block = as.integer(row_number() == 1)) |>
  ungroup()

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
  Ndata                = Ndata,
  Nsubjects            = Nsubjects,
  subject_trial        = df$subject_trial,
  choice               = df$choice,
  first_trial_in_block = df$first_trial_in_block
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

print(fit, pars = c("delta_pop", "rho_pop"))

draws <- rstan::extract(fit)

#### SAVE GROUP DRAWS ####
draws_group <- tibble(
  delta_pop = as.numeric(draws$delta_pop),
  rho_pop   = as.numeric(draws$rho_pop)
)
write_csv(draws_group, file.path(DRAWS_DIR, "posterior_draws_group.csv"))

#### SAVE SUBJECT DRAWS ####
sbj_param_map <- list(delta = draws$delta_sbj, rho = draws$rho_sbj)

draws_subject <- lapply(names(sbj_param_map), function(pname) {
  arr <- sbj_param_map[[pname]]
  lapply(seq_len(Nsubjects), function(s) {
    draws_s <- arr[, s]
    tibble(
      participant        = participants[s],
      understood_eq_felt = participant_map$understood_eq_felt[s],
      param              = paste0(pname, "_dr"),
      median             = median(draws_s),
      lo90               = unname(quantile(draws_s, 0.05)),
      hi90               = unname(quantile(draws_s, 0.95))
    )
  }) |> bind_rows()
}) |> bind_rows()

write_csv(draws_subject, file.path(DRAWS_DIR, "posterior_draws_subject.csv"))

#### SAVE TRIAL-LEVEL E MEDIANS ####
E_draws  <- draws$E_trial               # [iterations, Ndata, 3]
E_median <- apply(E_draws, c(2, 3), median)

e_trial_df <- df |>
  select(participant, block_number, trial_number, choice) |>
  mutate(E1 = E_median[, 1], E2 = E_median[, 2], E3 = E_median[, 3])
write_csv(e_trial_df, file.path(DRAWS_DIR, "e_trial_median.csv"))

cat("\nSaved group draws    ->", file.path(DRAWS_DIR, "posterior_draws_group.csv"), "\n")
cat("Saved subject draws   ->", file.path(DRAWS_DIR, "posterior_draws_subject.csv"), "\n")
cat("Saved E trial median  ->", file.path(DRAWS_DIR, "e_trial_median.csv"), "\n")
