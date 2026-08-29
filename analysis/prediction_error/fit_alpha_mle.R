rm(list = ls())

#### SETUP ####
library(dplyr)
library(readr)
library(stringr)

DATA_DIR <- "../../data/ioc-all-fixed-pilot/task"
OUT_CSV  <- "subject_alpha_mle.csv"

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
cat(sprintf("Participants: %d, trials: %d\n", length(participants), nrow(df)))

#### MLE FIT: classic Q-learning + streak-based perseveration (unchosen E -> 0) ####
# Mirrors models/classic_qval_and_unchosen_eval_zero/classic_qval_and_unchosen_eval_zero.stan
neg_log_lik <- function(par, choice, reward) {
  alpha_rl <- plogis(par[1])
  delta    <- plogis(par[2])
  beta_rl  <- exp(par[3])
  beta_per <- par[4]

  Q <- rep(0.5, 3)
  E <- rep(0, 3)
  streak <- 0L
  prev_choice <- 0L
  ll <- 0

  for (t in seq_along(choice)) {
    logits <- beta_rl * Q + beta_per * E
    logits <- logits - max(logits)
    p <- exp(logits) / sum(exp(logits))
    ll <- ll + log(p[choice[t]])

    Q[choice[t]] <- Q[choice[t]] + alpha_rl * (reward[t] - Q[choice[t]])

    if (choice[t] == prev_choice) streak <- streak + 1L else streak <- 1L
    prev_choice <- choice[t]

    E <- rep(0, 3)
    E[choice[t]] <- delta^(streak - 1)
  }

  -ll
}

fit_subject <- function(pid) {
  d <- df |> filter(participant == pid)
  fit <- optim(
    par     = c(0, 0, 0, 0),
    fn      = neg_log_lik,
    choice  = d$choice,
    reward  = d$reward,
    method  = "BFGS"
  )
  data.frame(
    participant = pid,
    alpha_rl    = plogis(fit$par[1]),
    delta       = plogis(fit$par[2]),
    beta_rl     = exp(fit$par[3]),
    beta_per    = fit$par[4],
    convergence = fit$convergence
  )
}

results <- lapply(participants, fit_subject) |> bind_rows()

results <- results |>
  mutate(
    understood_eq_felt = !(participant %in% MISUNDERSTOOD) & !(participant %in% FELT_DIFFERENT)
  )

write_csv(results, OUT_CSV)
cat(sprintf("\nSaved: %s (%d subjects, %d non-converged)\n",
            OUT_CSV, nrow(results), sum(results$convergence != 0)))
