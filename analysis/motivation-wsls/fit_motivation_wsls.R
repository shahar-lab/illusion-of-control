rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(cmdstanr)
library(posterior)

args <- commandArgs(trailingOnly = TRUE)
LAG  <- if (length(args) >= 1) as.integer(args[1]) else 1

DATA_DIR  <- "../../data/ioc-task/pilot20"
DRAWS_DIR <- "bayesian_draws"
OUT_CSV   <- file.path(DRAWS_DIR, paste0("posterior_draws_motiv_", LAG, "back.csv"))

dir.create(DRAWS_DIR, showWarnings = FALSE)
cat("Running motivation x WSLS analysis | LAG =", LAG, "\n")

INCLUDED_IDS <- c(
  "6980990e5c9007100eb282b6", "69808775dc84b90f4adafb2f", "61563a4b0def9000ccc976ec",
  "60f19a691466276fe085b461", "69dac2125e535db5a698ea18", "6980792fded33a62e27ce7cc",
  "6981150699107501d80e74b6", "667bd577710d52a05ac09036", "6981e6c2e26c88d954f297eb",
  "69d555ce85e30d6215e559d9", "69829236d776a93cf3afa632", "69d5525ec7afcfce08d8608b",
  "6980d9a70a7862a47c69046d", "6984a9246122d3bd4ca0833e", "69728435c9476fe76dd2ab2f",
  "69e913482ae5864d44e6387c", "697a645e36e6f14eea2b396b", "698341d57fe7b870bddf91b8",
  "697caeea2ec1c2604535f8aa", "62ebe597372fdef388b734b3"
)

#### LOAD DATA ####
all_files <- list.files(DATA_DIR, full.names = TRUE)
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(f, "[a-f0-9]{24}")
  if (is.na(pid) || !(pid %in% INCLUDED_IDS)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df <- bind_rows(df_list)

#### COMPUTE MOTIVATION SCORE PER SUBJECT ####
# IMI (Intrinsic Motivation Inventory): mean of all non-attention items, reverse-scored
motiv_scores <- df |>
  filter(phase == "motivation_imi", trial_type == "survey-likert") |>
  filter(!as.logical(attention)) |>
  mutate(
    resp_val   = as.integer(str_extract(response, "(?<=:)\\d+")),
    is_flipped = as.logical(flipped),
    score      = if_else(is_flipped, 6L - resp_val, resp_val)
  ) |>
  group_by(participant) |>
  summarise(motivation = mean(score), .groups = "drop") |>
  mutate(motivation_z = as.vector(scale(motivation)))

cat("Motivation scores (N =", nrow(motiv_scores), "):\n")
print(motiv_scores)

#### FILTER TO VALID STAY/SWITCH TRIALS ####
df_task <- df |>
  filter(task == "gambling_choice") |>
  group_by(participant, block_number) |>
  mutate(
    choice_key_nback      = lag(choice_key,      n = LAG),
    reward_nback          = lag(reward,           n = LAG),
    is_choice_valid_nback = lag(is_choice_valid,  n = LAG)
  ) |>
  ungroup() |>
  filter(
    block_number          != "training",
    trial_number          > LAG,
    is_choice_valid       == TRUE,
    is_choice_valid_nback == TRUE,
    !is.na(choice_key_nback),
    !is.na(reward_nback),
    choice_key_nback      != unavailable_key
  ) |>
  mutate(
    stay_ch      = as.integer(choice_key == choice_key_nback),
    reward_nback = as.integer(reward_nback)
  )

# Subject index aligned with motivation scores
subj_map <- tibble(participant = unique(df_task$participant)) |>
  mutate(subj_idx = row_number()) |>
  left_join(motiv_scores, by = "participant")

df_task <- df_task |>
  left_join(subj_map |> select(participant, subj_idx), by = "participant")

cat("Total observations:", nrow(df_task), "\n")
cat("N subjects:", nrow(subj_map), "\n")

#### STAN MODEL ####
# Hierarchical WSLS with motivation as group-level predictor of WSLS beta:
#   beta_sbj[j] = beta_mu + gamma * motivation_z[j] + beta_sigma * beta_z[j]
# gamma captures whether higher motivation predicts a stronger WSLS effect.
stan_code <- "
data {
  int<lower=0> N;
  int<lower=0> N_subj;
  array[N] int<lower=1,upper=N_subj> subj_id;
  array[N] int<lower=0,upper=1> stay_ch;
  vector[N] reward_nback;
  vector[N_subj] motivation;
}
parameters {
  real alpha_mu;
  real beta_mu;
  real gamma;
  real<lower=0> alpha_sigma;
  real<lower=0> beta_sigma;
  vector[N_subj] alpha_z;
  vector[N_subj] beta_z;
}
transformed parameters {
  vector[N_subj] alpha = alpha_mu + alpha_sigma * alpha_z;
  vector[N_subj] beta  = beta_mu + gamma * motivation + beta_sigma * beta_z;
}
model {
  alpha_mu    ~ normal(0, 2);
  beta_mu     ~ normal(0, 2);
  gamma       ~ normal(0, 1);
  alpha_sigma ~ normal(0, 1);
  beta_sigma  ~ normal(0, 1);
  alpha_z     ~ std_normal();
  beta_z      ~ std_normal();
  for (n in 1:N)
    stay_ch[n] ~ bernoulli_logit(alpha[subj_id[n]] + beta[subj_id[n]] * reward_nback[n]);
}
"

stan_file <- write_stan_file(stan_code)
model     <- cmdstan_model(stan_file)

#### SAMPLE ####
fit <- model$sample(
  data = list(
    N            = nrow(df_task),
    N_subj       = nrow(subj_map),
    subj_id      = df_task$subj_idx,
    stay_ch      = df_task$stay_ch,
    reward_nback = df_task$reward_nback,
    motivation   = subj_map$motivation_z
  ),
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 1000,
  iter_sampling   = 1000,
  adapt_delta     = 0.95,
  refresh         = 200
)

fit$summary(variables = c("alpha_mu", "beta_mu", "gamma", "alpha_sigma", "beta_sigma"))

#### SAVE DRAWS ####
beta_vars <- paste0("beta[", seq_len(nrow(subj_map)), "]")

draws_wide <- fit$draws(variables = c("gamma", beta_vars), format = "df") |>
  select(gamma, all_of(beta_vars), .draw)

draws_long <- draws_wide |>
  pivot_longer(cols = all_of(beta_vars), names_to = "var", values_to = "beta") |>
  mutate(subj_idx = as.integer(str_extract(var, "\\d+"))) |>
  left_join(subj_map, by = "subj_idx") |>
  select(participant, motivation, motivation_z, .draw, beta, gamma)

write_csv(draws_long, OUT_CSV)
cat("\nSaved", nrow(draws_long), "rows ->", OUT_CSV, "\n")

if (LAG == 1) {
  write_csv(subj_map, file.path(DRAWS_DIR, "participant_map.csv"))
  cat("Saved participant_map.csv\n")
}
