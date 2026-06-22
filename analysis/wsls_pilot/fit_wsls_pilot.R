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

DATA_DIR  <- "../../data/ioc-all-fixed-pilot/task"
DRAWS_DIR <- "bayesian_draws"
OUT_CSV   <- file.path(DRAWS_DIR, paste0("posterior_draws_", LAG, "back.csv"))

dir.create(DRAWS_DIR, showWarnings = FALSE)
cat("Running wsls pilot analysis | LAG =", LAG, "\n")

#### LOAD DATA ####
all_files <- list.files(DATA_DIR, pattern = "\\.csv$", full.names = TRUE)

df_list <- list()
for (f in all_files) {
  pid <- str_extract(f, "[a-f0-9]{24}")
  if (is.na(pid)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df <- bind_rows(df_list)
cat("Loaded", n_distinct(df$participant), "subjects\n")

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
    !is.na(reward_nback),
    choice_key_nback      != unavailable_key
  ) |>
  mutate(
    stay_ch      = as.integer(choice_key == choice_key_nback),
    reward_nback = as.integer(reward_nback)
  )

cat("Total observations:", nrow(df), "\n")
cat("P(stay | no reward):", mean(df$stay_ch[df$reward_nback == 0]), "\n")
cat("P(stay | reward):   ", mean(df$stay_ch[df$reward_nback == 1]), "\n")

#### SUBJECT-LEVEL PROPORTIONS ####
subj_props <- df |>
  group_by(participant, reward_nback) |>
  summarise(p_stay = mean(stay_ch), .groups = "drop") |>
  mutate(
    condition = ifelse(reward_nback == 1, "Rewarded", "Not rewarded"),
    lag       = LAG
  )

write_csv(subj_props, file.path(DRAWS_DIR, paste0("subj_props_", LAG, "back.csv")))
cat("Saved subject proportions\n")

#### STAN MODEL ####
stan_code <- "
data {
  int<lower=0> N;
  array[N] int<lower=0,upper=1> stay_ch;
  vector[N] reward_nback;
}
parameters {
  real alpha;
  real beta;
}
model {
  alpha ~ normal(0, 2);
  beta  ~ normal(0, 2);
  stay_ch ~ bernoulli_logit(alpha + beta * reward_nback);
}
generated quantities {
  real p_stay_noreward = inv_logit(alpha);
  real p_stay_reward   = inv_logit(alpha + beta);
}
"

stan_file <- write_stan_file(stan_code)
model     <- cmdstan_model(stan_file)

#### SAMPLE ####
fit <- model$sample(
  data = list(
    N            = nrow(df),
    stay_ch      = df$stay_ch,
    reward_nback = df$reward_nback
  ),
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 1000,
  iter_sampling   = 1000,
  refresh         = 200
)

fit$summary(variables = c("alpha", "beta", "p_stay_noreward", "p_stay_reward"))

#### SAVE DRAWS ####
draws <- fit$draws(
  variables = c("alpha", "beta", "p_stay_noreward", "p_stay_reward"),
  format    = "df"
) |>
  select(alpha, beta, p_stay_noreward, p_stay_reward)

write_csv(draws, OUT_CSV)
cat("\nSaved", nrow(draws), "posterior draws ->", OUT_CSV, "\n")
