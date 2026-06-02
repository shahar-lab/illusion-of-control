rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(rstan)

rstan_options(auto_write = TRUE)
options(mc.cores = 4)

DATA_DIR  <- "../../data/ioc-all-pilot10"
DRAWS_DIR <- "bayesian_draws"

dir.create(DRAWS_DIR, showWarnings = FALSE)

# Map choice_color to machine index (1=blue, 2=green, 3=red)
# Matching belief_blue, belief_green, belief_red columns
COLOR_TO_IDX <- c(blue = 1L, green = 2L, red = 3L)

#### LOAD DATA ####
all_files <- list.files(DATA_DIR, pattern = "\\.csv$", full.names = TRUE)
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(basename(f), "[a-f0-9]{24}")
  if (is.na(pid)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df_all <- bind_rows(df_list)

#### EXTRACT BELIEFS (one row per participant) ####
beliefs <- df_all |>
  filter(!is.na(trial_name) & trial_name == "belief_survey") |>
  group_by(participant) |>
  slice(1) |>
  ungroup() |>
  select(participant, belief_blue, belief_green, belief_red) |>
  mutate(across(c(belief_blue, belief_green, belief_red), as.integer))

cat("Participants with beliefs:", nrow(beliefs), "\n")

#### PREPARE GAMBLING TRIALS ####
df <- df_all |>
  filter(task == "gambling_choice", block_number != "training", is_choice_valid == TRUE) |>
  mutate(
    choice_idx = COLOR_TO_IDX[choice_color],
    reward     = as.integer(reward)
  ) |>
  filter(!is.na(choice_idx), !is.na(reward)) |>
  arrange(participant, as.integer(block_number), trial_number)

subj_map <- tibble(participant = sort(unique(df$participant))) |>
  mutate(subj_idx = row_number())

df <- df |> left_join(subj_map, by = "participant")

cat("Total trials:", nrow(df), "\n")
cat("N subjects:", nrow(subj_map), "\n")

#### STAN MODEL ####
# Hierarchical alpha-beta RL model (delta learning, softmax policy).
# Q values initialized at 0.5 per session (no block resets), so final Q
# reflects accumulated experience across all 150 trials.
stan_code <- "
data {
  int<lower=1> N;
  int<lower=1> N_subj;
  array[N] int<lower=1,upper=N_subj> subj_id;
  array[N] int<lower=1,upper=3> choice;
  array[N] int<lower=0,upper=1> reward;
}
parameters {
  real mu_alpha_logit;
  real mu_log_beta;
  real<lower=0> sigma_alpha;
  real<lower=0> sigma_beta;
  vector[N_subj] alpha_z;
  vector[N_subj] beta_z;
}
transformed parameters {
  vector<lower=0,upper=1>[N_subj] alpha_sbj;
  vector<lower=0>[N_subj] beta_sbj;
  vector[N] log_lik_trials;

  for (s in 1:N_subj) {
    alpha_sbj[s] = inv_logit(mu_alpha_logit + sigma_alpha * alpha_z[s]);
    beta_sbj[s]  = exp(mu_log_beta + sigma_beta * beta_z[s]);
  }

  {
    array[N_subj] vector[3] Q;
    for (s in 1:N_subj) Q[s] = rep_vector(0.5, 3);
    for (t in 1:N) {
      int s = subj_id[t];
      vector[3] q_scaled = beta_sbj[s] * Q[s];
      log_lik_trials[t] = q_scaled[choice[t]] - log_sum_exp(q_scaled);
      Q[s][choice[t]] += alpha_sbj[s] * (reward[t] - Q[s][choice[t]]);
    }
  }
}
model {
  mu_alpha_logit ~ normal(0, 2);
  mu_log_beta    ~ normal(0, 2);
  sigma_alpha    ~ normal(0, 1);
  sigma_beta     ~ normal(0, 1);
  alpha_z        ~ std_normal();
  beta_z         ~ std_normal();
  target += sum(log_lik_trials);
}
generated quantities {
  matrix[N_subj, 3] Q_final;
  {
    array[N_subj] vector[3] Q;
    for (s in 1:N_subj) Q[s] = rep_vector(0.5, 3);
    for (t in 1:N) {
      int s = subj_id[t];
      Q[s][choice[t]] += alpha_sbj[s] * (reward[t] - Q[s][choice[t]]);
    }
    for (s in 1:N_subj) {
      for (c in 1:3) Q_final[s, c] = Q[s][c];
    }
  }
}
"

#### SAMPLE ####
fit <- stan(
  model_code = stan_code,
  data = list(
    N       = nrow(df),
    N_subj  = nrow(subj_map),
    subj_id = df$subj_idx,
    choice  = df$choice_idx,
    reward  = df$reward
  ),
  chains   = 4,
  iter     = 2000,
  warmup   = 1000,
  refresh  = 200
)

print(fit, pars = c("mu_alpha_logit", "mu_log_beta", "sigma_alpha", "sigma_beta"))

#### EXTRACT FINAL Q-VALUES (posterior mean per subject per machine) ####
draws     <- rstan::extract(fit)
Q_arr     <- draws$Q_final  # N_draws x N_subj x 3
Q_means   <- apply(Q_arr, c(2, 3), mean)  # N_subj x 3
colnames(Q_means) <- c("Q_blue", "Q_green", "Q_red")

q_df <- as_tibble(Q_means) |>
  mutate(subj_idx = row_number()) |>
  left_join(subj_map, by = "subj_idx") |>
  select(participant, Q_blue, Q_green, Q_red)

# Also save alpha and beta estimates
alpha_means <- apply(draws$alpha_sbj, 2, mean)
beta_means  <- apply(draws$beta_sbj,  2, mean)
params_df   <- subj_map |>
  mutate(alpha = alpha_means, beta = beta_means) |>
  select(participant, alpha, beta)

write_csv(params_df, file.path(DRAWS_DIR, "rl_params.csv"))
cat("Saved RL parameters ->", file.path(DRAWS_DIR, "rl_params.csv"), "\n")

#### COMBINE WITH BELIEFS ####
combined <- q_df |>
  left_join(beliefs, by = "participant") |>
  select(participant, Q_blue, Q_green, Q_red, belief_blue, belief_green, belief_red)

write_csv(combined, file.path(DRAWS_DIR, "rl_qvalues.csv"))
cat("Saved Q-values + beliefs ->", file.path(DRAWS_DIR, "rl_qvalues.csv"), "\n")
print(combined)
