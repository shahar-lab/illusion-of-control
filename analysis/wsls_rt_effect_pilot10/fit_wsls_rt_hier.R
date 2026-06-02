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
OUT_CSV   <- file.path(DRAWS_DIR, paste0("posterior_draws_hier_", LAG, "back.csv"))

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

df <- bind_rows(df_list)

#### FILTER TO VALID STAY/SWITCH TRIALS ####
df <- df |>
  filter(task == "gambling_choice") |>
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
  )

subj_map <- tibble(participant = sort(unique(df$participant))) |>
  mutate(subj_idx = row_number())

df <- df |> left_join(subj_map, by = "participant")

cat("Total observations:", nrow(df), "\n")
cat("N subjects:", nrow(subj_map), "\n")

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

#### SAMPLE ####
fit <- stan(
  model_code = stan_code,
  data = list(
    N            = nrow(df),
    N_subj       = nrow(subj_map),
    subj_id      = df$subj_idx,
    stay_ch      = df$stay_ch,
    reward_nback = df$reward_nback
  ),
  chains   = 4,
  iter     = 2000,
  warmup   = 1000,
  refresh  = 200
)

print(fit, pars = c("alpha_mu", "beta_mu", "alpha_sigma", "beta_sigma"))

#### SAVE DRAWS — long format matching pilot20 style ####
beta_vars <- paste0("beta[", seq_len(nrow(subj_map)), "]")

draws_wide <- as.data.frame(fit)[, beta_vars, drop = FALSE]
draws_wide$.draw <- seq_len(nrow(draws_wide))

draws_long <- draws_wide |>
  pivot_longer(cols = all_of(beta_vars), names_to = "var", values_to = "beta") |>
  mutate(subj_idx = as.integer(gsub("beta\\[|\\]", "", var))) |>
  left_join(subj_map, by = "subj_idx") |>
  select(participant, .draw, beta)

write_csv(draws_long, OUT_CSV)
cat("\nSaved", nrow(draws_long), "rows ->", OUT_CSV, "\n")

if (LAG == 1) {
  write_csv(subj_map, file.path(DRAWS_DIR, "participant_map.csv"))
  cat("Saved participant_map.csv\n")
}
