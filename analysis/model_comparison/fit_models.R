rm(list = ls())

# Fits two models per subject via MLE (optim) on the new 3-arm bandit data.
#
# Model 1 — Q-values + perseveration (alpha, beta, kappa)
#   Q[k] initialised at 0.5 per block, updated via Rescorla-Wagner.
#   P(choice=k) = softmax( beta * Q[k] + kappa * I(k == prev_choice) )
#
# Model 2 — Perseveration only (kappa)
#   No Q-values. P(choice=k) = softmax( kappa * I(k == prev_choice) )
#   First trial of each block: uniform (1/3) over all machines.
#
# Outputs are structured so that a future omega mixture model can be added:
#   P_omega(choice) = omega * P_model1(choice) + (1 - omega) * P_model2(choice)
# Both models save trial-by-trial P(actual_choice) and the full prob vector.

library(dplyr)
library(readr)
library(stringr)

DATA_DIR <- "../../data/ioc-all-fixed-pilot/task"
OUT_DIR  <- "output"
dir.create(OUT_DIR, showWarnings = FALSE)

MACHINES <- c("arrowup", "arrowleft", "arrowright")
N_M      <- length(MACHINES)

#### LOAD DATA ####
KEEP_COLS <- c("task", "block_number", "trial_number", "choice_key", "reward", "is_choice_valid")
files     <- list.files(DATA_DIR, full.names = TRUE, pattern = "\\.csv$")
df_list   <- list()

for (f in files) {
  pid <- str_extract(basename(f), "[a-f0-9]{24}")
  if (is.na(pid)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |>
    select(any_of(KEEP_COLS)) |>
    mutate(participant = pid)
}

df <- bind_rows(df_list) |>
  filter(task == "gambling_choice", block_number != "training", is_choice_valid == TRUE) |>
  mutate(
    block_number = as.integer(block_number),
    trial_number = as.integer(trial_number),
    reward       = as.numeric(reward),
    choice_idx   = match(choice_key, MACHINES)
  ) |>
  arrange(participant, block_number, trial_number)

stopifnot(!any(is.na(df$choice_idx)))  # every choice maps to a machine
cat("Total valid trials:", nrow(df), "  Subjects:", n_distinct(df$participant), "\n")

#### HELPERS ####
log_softmax <- function(logits) {
  m <- max(logits)
  logits - (m + log(sum(exp(logits - m))))
}

#### MODEL 1: Q-VALUES + PERSEVERATION ####

neg_log_lik_qkappa <- function(par, trials) {
  alpha <- plogis(par[1])  # learning rate  ∈ (0, 1)
  beta  <- exp(par[2])     # inverse temp   > 0
  kappa <- par[3]          # perseveration  unconstrained

  nll <- 0
  for (blk in sort(unique(trials$block_number))) {
    bt             <- trials[trials$block_number == blk, ]
    Q              <- rep(0.5, N_M)   # Q-values reset each block
    prev_idx       <- NA

    for (i in seq_len(nrow(bt))) {
      ci      <- bt$choice_idx[i]
      perserv <- rep(0, N_M)
      if (!is.na(prev_idx)) perserv[prev_idx] <- kappa

      logits    <- beta * Q + perserv
      log_probs <- log_softmax(logits)
      nll       <- nll - log_probs[ci]

      Q[ci]    <- Q[ci] + alpha * (bt$reward[i] - Q[ci])  # RW update
      prev_idx <- ci
    }
  }
  nll
}

# Trial-by-trial predictions under fitted Model 1 params
trial_preds_qkappa <- function(par, trials) {
  alpha <- plogis(par[1])
  beta  <- exp(par[2])
  kappa <- par[3]

  rows <- vector("list", nrow(trials))
  row_i <- 1L
  for (blk in sort(unique(trials$block_number))) {
    bt       <- trials[trials$block_number == blk, ]
    Q        <- rep(0.5, N_M)
    prev_idx <- NA

    for (i in seq_len(nrow(bt))) {
      ci      <- bt$choice_idx[i]
      perserv <- rep(0, N_M)
      if (!is.na(prev_idx)) perserv[prev_idx] <- kappa

      probs <- exp(log_softmax(beta * Q + perserv))

      rows[[row_i]] <- list(
        participant   = bt$participant[i],
        block_number  = blk,
        trial_number  = bt$trial_number[i],
        choice_key    = bt$choice_key[i],
        reward        = bt$reward[i],
        p_qkappa      = probs[ci],           # P(actual choice | model 1)
        p_qkappa_m1   = probs[1],            # full vector for omega model
        p_qkappa_m2   = probs[2],
        p_qkappa_m3   = probs[3]
      )
      row_i <- row_i + 1L

      Q[ci]    <- Q[ci] + alpha * (bt$reward[i] - Q[ci])
      prev_idx <- ci
    }
  }
  bind_rows(lapply(rows, as.data.frame))
}

#### MODEL 2: PERSEVERATION ONLY ####

neg_log_lik_kappa <- function(par, trials) {
  kappa <- par[1]

  nll <- 0
  for (blk in sort(unique(trials$block_number))) {
    bt       <- trials[trials$block_number == blk, ]
    prev_idx <- NA

    for (i in seq_len(nrow(bt))) {
      ci     <- bt$choice_idx[i]
      logits <- rep(0, N_M)
      if (!is.na(prev_idx)) logits[prev_idx] <- kappa

      log_probs <- log_softmax(logits)
      nll       <- nll - log_probs[ci]
      prev_idx  <- ci
    }
  }
  nll
}

trial_preds_kappa <- function(par, trials) {
  kappa <- par[1]

  rows  <- vector("list", nrow(trials))
  row_i <- 1L
  for (blk in sort(unique(trials$block_number))) {
    bt       <- trials[trials$block_number == blk, ]
    prev_idx <- NA

    for (i in seq_len(nrow(bt))) {
      ci     <- bt$choice_idx[i]
      logits <- rep(0, N_M)
      if (!is.na(prev_idx)) logits[prev_idx] <- kappa

      probs <- exp(log_softmax(logits))

      rows[[row_i]] <- list(
        p_kappa    = probs[ci],
        p_kappa_m1 = probs[1],
        p_kappa_m2 = probs[2],
        p_kappa_m3 = probs[3]
      )
      row_i    <- row_i + 1L
      prev_idx <- ci
    }
  }
  bind_rows(lapply(rows, as.data.frame))
}

#### FIT PER SUBJECT ####
subjects       <- sort(unique(df$participant))
params_qk_list <- list()
params_k_list  <- list()
preds_list     <- list()

# Starting points for Model 1 (multiple restarts to avoid local minima)
# Parameter space: [qlogis(alpha), log(beta), kappa]
# Bounds keep beta in (exp(-3), exp(4)) ≈ (0.05, 55) and alpha in (0, 1)
LB_QK <- c(-6, -3, -8)
UB_QK <- c( 6,  4,  8)

starts_qk <- list(
  c(0,      log(2), 0),   # alpha=0.5, beta=2, kappa=0
  c(qlogis(0.2), log(5),  1.0),
  c(qlogis(0.8), log(1), -1.0),
  c(qlogis(0.1), log(8),  2.0)
)

for (pid in subjects) {
  cat("Fitting:", pid, "\n")
  trials <- df[df$participant == pid, ]
  n_t    <- nrow(trials)

  # --- Model 1: Q + perseveration ---
  best1 <- NULL
  for (s in starts_qk) {
    opt <- tryCatch(
      optim(s, neg_log_lik_qkappa, trials = trials, method = "L-BFGS-B",
            lower = LB_QK, upper = UB_QK,
            control = list(maxit = 2000)),
      error = function(e) list(value = Inf, par = s, convergence = 99)
    )
    if (is.null(best1) || opt$value < best1$value) best1 <- opt
  }

  params_qk_list[[pid]] <- data.frame(
    participant = pid,
    alpha       = plogis(best1$par[1]),
    beta        = exp(best1$par[2]),
    kappa       = best1$par[3],
    neg_ll      = best1$value,
    aic         = 2 * 3 + 2 * best1$value,
    bic         = log(n_t) * 3 + 2 * best1$value,
    convergence = best1$convergence
  )

  # --- Model 2: perseveration only ---
  best2 <- tryCatch(
    optim(0, neg_log_lik_kappa, trials = trials,
          method = "Brent", lower = -10, upper = 10),
    error = function(e) list(value = Inf, par = 0, convergence = 99)
  )

  params_k_list[[pid]] <- data.frame(
    participant = pid,
    kappa       = best2$par,
    neg_ll      = best2$value,
    aic         = 2 * 1 + 2 * best2$value,
    bic         = log(n_t) * 1 + 2 * best2$value,
    convergence = best2$convergence
  )

  # --- Trial predictions (omega-ready) ---
  p1 <- trial_preds_qkappa(best1$par, trials)
  p2 <- trial_preds_kappa(best2$par,  trials)
  preds_list[[pid]] <- bind_cols(p1, p2)
}

#### SAVE OUTPUTS ####
params_qkappa <- bind_rows(params_qk_list)
params_kappa  <- bind_rows(params_k_list)
preds_all     <- bind_rows(preds_list)

write_csv(params_qkappa, file.path(OUT_DIR, "params_qkappa.csv"))
write_csv(params_kappa,  file.path(OUT_DIR, "params_kappa.csv"))
write_csv(preds_all,     file.path(OUT_DIR, "trial_predictions.csv"))

#### SUMMARY ####
cat("\n=== Model 1: Q + perseveration (alpha, beta, kappa) ===\n")
print(params_qkappa |> select(participant, alpha, beta, kappa, aic, bic))

cat("\n=== Model 2: Perseveration only (kappa) ===\n")
print(params_kappa |> select(participant, kappa, aic, bic))

comp <- data.frame(
  participant  = params_qkappa$participant,
  delta_aic    = params_qkappa$aic - params_kappa$aic,  # negative = Model 1 better
  delta_bic    = params_qkappa$bic - params_kappa$bic
)
cat("\n=== Model comparison (delta AIC/BIC: negative = Q-kappa better) ===\n")
print(comp)
cat("Subjects where Q-kappa wins (delta AIC < 0):",
    sum(comp$delta_aic < 0), "/", nrow(comp), "\n")
cat("Group mean delta AIC:", round(mean(comp$delta_aic), 2), "\n")
