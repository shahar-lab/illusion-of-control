rm(list = ls())

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(rstan)

options(mc.cores = 4)
rstan_options(auto_write = TRUE)

DATA_DIR  <- "../../data/ioc-all-fixed-pilot/task"
DRAWS_DIR <- "bayesian_draws"
dir.create(DRAWS_DIR, showWarnings = FALSE)

#### LOAD DATA ####
files   <- list.files(DATA_DIR, full.names = TRUE, pattern = "\\.csv$")
df_list <- list()

KEEP_COLS <- c("task", "block_number", "trial_number", "choice_key", "reward", "is_choice_valid")

for (f in files) {
  pid <- str_extract(basename(f), "[a-f0-9]{24}")
  if (is.na(pid)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |>
    select(any_of(KEEP_COLS)) |>
    mutate(participant = pid)
}

df <- bind_rows(df_list)
cat("Loaded", length(df_list), "participants\n")

#### FILTER TO VALID STAY/SWITCH TRIALS ####
df <- df |>
  filter(task == "gambling_choice", block_number != "training") |>
  group_by(participant, block_number) |>
  mutate(
    choice_prev   = lag(choice_key,      n = 1),
    reward_prev   = lag(reward,          n = 1),
    is_valid_prev = lag(is_choice_valid, n = 1)
  ) |>
  ungroup() |>
  filter(
    trial_number    > 1,
    is_choice_valid == TRUE,
    is_valid_prev   == TRUE,
    !is.na(choice_prev),
    !is.na(reward_prev)
  ) |>
  mutate(
    stay_ch     = as.integer(choice_key == choice_prev),
    reward_prev = as.integer(reward_prev)
  )

subj_map <- tibble(participant = unique(df$participant)) |>
  mutate(subj_idx = row_number())

df <- df |> left_join(subj_map, by = "participant")

cat("Total observations:", nrow(df), "\n")
cat("N subjects:", nrow(subj_map), "\n")

#### HIERARCHICAL STAN MODEL ####
# stay ~ bernoulli_logit(alpha[j] + beta[j] * reward_prev)
# alpha[j] = alpha_mu + alpha_sigma * alpha_z[j]   (random intercept)
# beta[j]  = beta_mu  + beta_sigma  * beta_z[j]    (random reward slope)
# beta_mu: group-level reward effect on log-odds of staying
stan_code <- "
data {
  int<lower=0> N;
  int<lower=0> N_subj;
  array[N] int<lower=1,upper=N_subj> subj_id;
  array[N] int<lower=0,upper=1> stay_ch;
  vector[N] reward_prev;
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
    stay_ch[n] ~ bernoulli_logit(alpha[subj_id[n]] + beta[subj_id[n]] * reward_prev[n]);
}
"

#### SAMPLE ####
fit <- stan(
  model_code      = stan_code,
  data = list(
    N           = nrow(df),
    N_subj      = nrow(subj_map),
    subj_id     = df$subj_idx,
    stay_ch     = df$stay_ch,
    reward_prev = df$reward_prev
  ),
  chains  = 4,
  iter    = 2000,
  warmup  = 1000,
  refresh = 200
)

cat("\n--- Group-level parameter summary ---\n")
print(fit, pars = c("alpha_mu", "beta_mu", "alpha_sigma", "beta_sigma"), digits_summary = 3)

#### SAVE GROUP-LEVEL DRAWS ####
group_ext   <- extract(fit, pars = c("alpha_mu", "beta_mu", "alpha_sigma", "beta_sigma"))
group_draws <- as.data.frame(group_ext)

write_csv(group_draws, file.path(DRAWS_DIR, "posterior_draws_group.csv"))
cat("\nSaved posterior_draws_group.csv (", nrow(group_draws), "draws)\n")

#### SAVE SUBJECT-LEVEL BETA DRAWS ####
beta_mat <- extract(fit, pars = "beta")$beta  # [draws x N_subj]

draws_long <- do.call(rbind, lapply(seq_len(ncol(beta_mat)), function(j) {
  data.frame(
    subj_idx = j,
    .draw    = seq_len(nrow(beta_mat)),
    beta     = beta_mat[, j]
  )
})) |>
  left_join(subj_map, by = "subj_idx") |>
  select(participant, subj_idx, .draw, beta)

write_csv(draws_long, file.path(DRAWS_DIR, "posterior_draws_subject_beta.csv"))
write_csv(subj_map,   file.path(DRAWS_DIR, "participant_map.csv"))
cat("Saved posterior_draws_subject_beta.csv and participant_map.csv\n")
