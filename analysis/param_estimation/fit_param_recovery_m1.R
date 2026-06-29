rm(list = ls())

#### SETUP ####
library(dplyr)
library(readr)
library(stringr)
library(cmdstanr)
library(posterior)

DATA_DIR   <- "../../data/ioc-all-fixed-pilot/task"
MODEL_FILE <- "../../models/rl_m1_3arm/rl_m1_3arm.stan"
DRAWS_DIR  <- "bayesian_draws_r"
OUT_GROUP  <- file.path(DRAWS_DIR, "posterior_draws_group_m1.csv")
OUT_SBJ    <- file.path(DRAWS_DIR, "posterior_draws_subject_m1.csv")

dir.create(DRAWS_DIR, showWarnings = FALSE)

KEY_TO_ARM <- c(arrowleft = 1L, arrowup = 2L, arrowright = 3L)

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

#### PREPARE STAN DATA ####
df <- df |>
  filter(
    task             == "gambling_choice",
    block_number     != "training",
    is_choice_valid  == TRUE
  ) |>
  mutate(
    block_number     = as.integer(block_number),
    trial_number     = as.integer(trial_number),
    reward           = as.numeric(reward),
    choice           = KEY_TO_ARM[choice_key]
  ) |>
  arrange(participant, block_number, trial_number) |>
  mutate(participant_idx = as.integer(factor(participant)))

# run_after[t] = consecutive same-arm run length ending at trial t (within block)
df <- df |>
  group_by(participant, block_number) |>
  mutate(
    same_as_prev = (choice == lag(choice)) & !is.na(lag(choice)),
    run_after    = {
      r <- integer(n())
      r[1] <- 1L
      for (i in seq(2, n())) r[i] <- if (same_as_prev[i]) r[i - 1] + 1L else 1L
      r
    }
  ) |>
  ungroup()

# persev_exp[t] = run_after[t-1] - 1, 0 at block starts
# prev_arm_oh[t,] = one-hot of choice[t-1], zeros at block starts
df <- df |>
  group_by(participant, block_number) |>
  mutate(
    persev_exp   = c(0, head(run_after, -1) - 1),
    prev_choice  = c(NA_integer_, head(choice, -1))
  ) |>
  ungroup() |>
  mutate(
    prev_arm1 = as.integer(!is.na(prev_choice) & prev_choice == 1L),
    prev_arm2 = as.integer(!is.na(prev_choice) & prev_choice == 2L),
    prev_arm3 = as.integer(!is.na(prev_choice) & prev_choice == 3L)
  )

# first_trial: 1 for first trial of each subject (Q reset)
df <- df |>
  group_by(participant) |>
  mutate(first_trial = as.integer(row_number() == 1)) |>
  ungroup()

Nsubjects <- n_distinct(df$participant)
cat("Total trials:", nrow(df), "| Subjects:", Nsubjects, "\n")

prev_arm_oh <- as.matrix(df[, c("prev_arm1", "prev_arm2", "prev_arm3")])

stan_data <- list(
  Ndata        = nrow(df),
  Nsubjects    = Nsubjects,
  subject_trial = df$participant_idx,
  choice       = df$choice,
  reward       = df$reward,
  first_trial  = df$first_trial,
  persev_exp   = df$persev_exp,
  prev_arm_oh  = prev_arm_oh
)

participant_map <- df |>
  distinct(participant, participant_idx) |>
  arrange(participant_idx)
write_csv(participant_map, file.path(DRAWS_DIR, "participant_map.csv"))

#### FIT MODEL ####
model <- cmdstan_model(MODEL_FILE)

fit <- model$sample(
  data            = stan_data,
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 1000,
  iter_sampling   = 1000,
  adapt_delta     = 0.95,
  refresh         = 200
)

group_vars <- c("mu_alpha", "mu_beta", "mu_kappa", "mu_delta",
                "alpha_pop", "beta_pop", "kappa_pop", "delta_pop")
sbj_vars   <- c(
  paste0("alpha_sbj[", 1:Nsubjects, "]"),
  paste0("beta_sbj[",  1:Nsubjects, "]"),
  paste0("kappa_sbj[", 1:Nsubjects, "]"),
  paste0("delta_sbj[", 1:Nsubjects, "]")
)

fit$summary(variables = group_vars)

#### SAVE DRAWS ####
draws_group <- fit$draws(variables = group_vars, format = "df") |>
  select(all_of(group_vars))

draws_sbj <- fit$draws(variables = sbj_vars, format = "df") |>
  select(all_of(sbj_vars))

write_csv(draws_group, OUT_GROUP)
write_csv(draws_sbj,   OUT_SBJ)

cat("\nSaved group draws   ->", OUT_GROUP, "\n")
cat("Saved subject draws ->", OUT_SBJ,   "\n")
