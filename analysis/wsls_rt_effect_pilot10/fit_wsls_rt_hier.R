rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(rstan)

rstan_options(auto_write = TRUE)
options(mc.cores = 4)

args <- commandArgs(trailingOnly = TRUE)
LAG  <- if (length(args) >= 1) as.integer(args[1]) else 1

DATA_DIR  <- "../../data/ioc-all-pilot10"
DRAWS_DIR <- "bayesian_draws"
OUT_CSV   <- file.path(DRAWS_DIR, paste0("wsls_rt_", LAG, "back.csv"))

dir.create(DRAWS_DIR, showWarnings = FALSE)
cat("Running hierarchical WSLS x RT (pilot10) | LAG =", LAG, "\n")

#### LOAD DATA ####
all_files <- list.files(DATA_DIR, pattern = "\\.csv$", full.names = TRUE)
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(basename(f), "[a-f0-9]{24}")
  if (is.na(pid)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df_all <- bind_rows(df_list)

#### COMPUTE MEDIAN RT PER PARTICIPANT (all valid trials) ####
rt_medians <- df_all |>
  filter(task == "gambling_choice", block_number != "training", is_choice_valid == TRUE) |>
  mutate(rt_num = as.numeric(rt)) |>
  group_by(participant) |>
  summarise(rt_median = median(rt_num, na.rm = TRUE), .groups = "drop")

#### FILTER TO VALID STAY/SWITCH TRIALS ####
df <- df_all |>
  filter(task == "gambling_choice") |>
  mutate(rt_num = as.numeric(rt)) |>
  group_by(participant, block_number) |>
  mutate(
    choice_key_nback      = lag(choice_key,     n = LAG),
    reward_nback          = lag(reward,          n = LAG),
    is_choice_valid_nback = lag(is_choice_valid, n = LAG)
  ) |>
  ungroup() |>
  filter(
    block_number          != "training",
    trial_number          > LAG,
    is_choice_valid       == TRUE,
    is_choice_valid_nback == TRUE,
    !is.na(choice_key_nback),
    !is.na(reward_nback)
  ) |>
  mutate(
    stay_ch      = as.integer(choice_key == choice_key_nback),
    reward_nback = as.integer(reward_nback)
  ) |>
  left_join(rt_medians, by = "participant") |>
  mutate(rt_group = if_else(rt_num <= rt_median, "fast", "slow")) |>
  filter(!is.na(rt_group))

cat("Total WSLS observations:", nrow(df), "\n")
cat("Fast trials:", sum(df$rt_group == "fast"), "\n")
cat("Slow trials:", sum(df$rt_group == "slow"), "\n")

#### STAN MODEL ####
stan_code <- "
data {
  int<lower=0> N;
  int<lower=0> N_subj;
  array[N] int<lower=1,upper=N_subj> subj_id;
  array[N] int<lower=0,upper=1> stay_ch;
  vector[N] reward_nback;
}
parameters {
  real alpha_mu;
  real beta_mu;
  real<lower=0> alpha_sigma;
  real<lower=0> beta_sigma;
  vector[N_subj] alpha_z;
  vector[N_subj] beta_z;
}
transformed parameters {
  vector[N_subj] alpha = alpha_mu + alpha_sigma * alpha_z;
  vector[N_subj] beta  = beta_mu  + beta_sigma  * beta_z;
}
model {
  alpha_mu    ~ normal(0, 2);
  beta_mu     ~ normal(0, 2);
  alpha_sigma ~ normal(0, 1);
  beta_sigma  ~ normal(0, 1);
  alpha_z     ~ std_normal();
  beta_z      ~ std_normal();
  for (n in 1:N)
    stay_ch[n] ~ bernoulli_logit(alpha[subj_id[n]] + beta[subj_id[n]] * reward_nback[n]);
}
"

#### FIT FUNCTION ####
fit_rt_group <- function(df_sub, group_label) {
  subj_map <- tibble(participant = sort(unique(df_sub$participant))) |>
    mutate(subj_idx = row_number())
  d <- df_sub |> left_join(subj_map, by = "participant")

  cat(sprintf("  [%s] %d trials across %d subjects\n",
    group_label, nrow(d), nrow(subj_map)))

  fit <- stan(
    model_code = stan_code,
    data = list(
      N            = nrow(d),
      N_subj       = nrow(subj_map),
      subj_id      = d$subj_idx,
      stay_ch      = d$stay_ch,
      reward_nback = d$reward_nback
    ),
    chains   = 4,
    iter     = 2000,
    warmup   = 1000,
    refresh  = 0
  )

  beta_mat <- rstan::extract(fit)$beta  # N_draws x N_subj

  tibble(
    participant = subj_map$participant,
    beta_med    = apply(beta_mat, 2, median),
    beta_lo     = apply(beta_mat, 2, quantile, 0.025),
    beta_hi     = apply(beta_mat, 2, quantile, 0.975)
  )
}

#### RUN ####
cat("Fitting fast model...\n")
res_fast <- fit_rt_group(filter(df, rt_group == "fast"), "fast")

cat("Fitting slow model...\n")
res_slow <- fit_rt_group(filter(df, rt_group == "slow"), "slow")

#### COMBINE AND SAVE ####
result <- res_fast |>
  rename(beta_fast = beta_med, beta_fast_lo = beta_lo, beta_fast_hi = beta_hi) |>
  left_join(
    res_slow |> rename(beta_slow = beta_med, beta_slow_lo = beta_lo, beta_slow_hi = beta_hi),
    by = "participant"
  )

write_csv(result, OUT_CSV)
cat("\nSaved", nrow(result), "participants ->", OUT_CSV, "\n")
print(result)
